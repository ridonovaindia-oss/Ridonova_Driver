import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../auth/auth_provider.dart';
import '../../wallet_model.dart';
import '../../wallet_provider.dart';

/// Bottom sheet allowing drivers with negative wallet balance / pending cash commission dues
/// to pay full or partial dues online via Razorpay and immediately unblock withdrawals & rides.
class PayDuesBottomSheet extends ConsumerStatefulWidget {
  const PayDuesBottomSheet({super.key});

  static Future<bool?> show(BuildContext context) async {
    final paid = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const PayDuesBottomSheet(),
    );
    if (paid == true && context.mounted) {
      AppFlushbar.success(
        context,
        title: 'Dues Paid Successfully!',
        message: 'Your driver wallet has been updated immediately.',
      );
    }
    return paid;
  }

  @override
  ConsumerState<PayDuesBottomSheet> createState() => _PayDuesBottomSheetState();
}

class _PayDuesBottomSheetState extends ConsumerState<PayDuesBottomSheet> {
  final TextEditingController _amountController = TextEditingController();
  late final Razorpay _razorpay;
  bool _isProcessing = false;
  bool _duesLoaded = false;
  String? _activeOrderId;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final wallet = ref.read(walletProvider).wallet;
      final due = wallet.effectivePendingDues;
      if (due > 0) {
        _amountController.text = due.toStringAsFixed(2);
      }
      await ref.read(walletProvider.notifier).fetchDues();
      if (!mounted) return;
      final refreshed = ref.read(walletProvider).wallet.effectivePendingDues;
      final currentVal = double.tryParse(_amountController.text.trim()) ?? 0.0;
      setState(() {
        _duesLoaded = true;
        if (refreshed > 0 && currentVal <= 0) {
          _amountController.text = refreshed.toStringAsFixed(2);
        }
      });
    });
  }

  @override
  void dispose() {
    _razorpay.clear();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _startDuesPayment(WalletModel wallet) async {
    if (_isProcessing) return;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount < 1.0) {
      AppFlushbar.error(
        context,
        title: 'Invalid Amount',
        message: 'Please enter a valid amount (minimum ₹1.00).',
      );
      return;
    }

    setState(() => _isProcessing = true);

    final orderData = await ref
        .read(walletProvider.notifier)
        .createDuesOrder(amount: amount);

    if (!mounted) return;

    if (orderData == null) {
      setState(() => _isProcessing = false);
      final err = ref.read(walletProvider).errorMessage;
      AppFlushbar.error(
        context,
        title: 'Payment Initialization Failed',
        message:
            err ?? 'Could not create dues payment order. Please try again.',
      );
      return;
    }

    final keyId =
        (orderData['keyId'] ??
                orderData['key_id'] ??
                orderData['razorpayKeyId'] ??
                wallet.razorpayKeyId ??
                '')
            .toString()
            .trim();
    final orderId =
        (orderData['orderId'] ?? orderData['order_id'] ?? orderData['id'] ?? '')
            .toString()
            .trim();
    final amountPaise =
        (orderData['amount'] as num?)?.toInt() ?? (amount * 100).round();

    if (keyId.isEmpty || orderId.isEmpty || amountPaise <= 0) {
      setState(() => _isProcessing = false);
      AppFlushbar.error(
        context,
        title: 'Payment Gateway Not Configured',
        message: 'Razorpay key or order ID missing from server response.',
      );
      return;
    }

    _activeOrderId = orderId;
    final user = ref.read(authProvider).user;
    final serverPrefill = orderData['prefill'] is Map
        ? Map<String, dynamic>.from(orderData['prefill'] as Map)
        : const <String, dynamic>{};

    final prefillName =
        (serverPrefill['name']?.toString().trim().isNotEmpty == true)
        ? serverPrefill['name'].toString().trim()
        : ((user?.fullName ?? '').trim().isNotEmpty
              ? (user?.fullName ?? '').trim()
              : 'Captain');
    final prefillContact =
        (serverPrefill['contact']?.toString().trim().isNotEmpty == true)
        ? serverPrefill['contact'].toString().trim()
        : (user?.phone ?? '').trim();
    final prefillEmail =
        (serverPrefill['email']?.toString().trim().isNotEmpty == true)
        ? serverPrefill['email'].toString().trim()
        : (user?.email ?? '').trim();

    final options = <String, dynamic>{
      'key': keyId,
      'amount': amountPaise,
      'currency': (orderData['currency']?.toString().trim().isNotEmpty == true)
          ? orderData['currency'].toString().trim()
          : 'INR',
      'name': 'Ridonova India',
      'description': 'Clear Driver Commission Dues',
      'order_id': orderId,
      'timeout': 300,
      'prefill': <String, String>{
        if (prefillContact.isNotEmpty) 'contact': prefillContact,
        if (prefillEmail.isNotEmpty) 'email': prefillEmail,
        if (prefillName.isNotEmpty) 'name': prefillName,
      },
      'theme': <String, String>{'color': '#EAB308'},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      AppFlushbar.error(
        context,
        title: 'Checkout Error',
        message: 'Could not launch payment checkout: $e',
      );
    }
  }

  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    final orderId = (response.orderId != null && response.orderId!.isNotEmpty)
        ? response.orderId!
        : (_activeOrderId ?? '');
    final paymentId = response.paymentId ?? '';
    final signature = response.signature ?? '';

    if (orderId.isEmpty || paymentId.isEmpty) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      AppFlushbar.error(
        context,
        title: 'Verification Pending',
        message:
            'Incomplete payment confirmation received. Please refresh your wallet.',
      );
      return;
    }

    final ok = await ref
        .read(walletProvider.notifier)
        .verifyDuesPayment(
          orderId: orderId,
          paymentId: paymentId,
          signature: signature,
        );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      final err = ref.read(walletProvider).errorMessage;
      AppFlushbar.error(
        context,
        title: 'Verification Pending',
        message:
            err ??
            'Payment received but verification failed. Please refresh your wallet or contact support.',
      );
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() => _isProcessing = false);
    AppFlushbar.error(
      context,
      title: 'Payment Cancelled / Failed',
      message: response.message?.isNotEmpty == true
          ? response.message!
          : 'Dues payment was not completed.',
    );
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    setState(() => _isProcessing = false);
    AppFlushbar.info(
      context,
      title: 'External Wallet Selected',
      message: 'Continuing payment via ${response.walletName ?? 'wallet'}...',
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    final wallet = walletState.wallet;
    final pendingDues = wallet.effectivePendingDues;
    final hasDues = pendingDues > 0;
    final minToUnblock = pendingDues > 999
        ? (pendingDues - 999).ceilToDouble()
        : 0.0;
    final showGatewayWarning =
        _duesLoaded &&
        !wallet.razorpayConfigured &&
        (wallet.razorpayKeyId == null || wallet.razorpayKeyId!.isEmpty);

    return PopScope(
      canPop: !_isProcessing,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: hasDues
                                  ? Colors.red.shade50
                                  : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.account_balance_wallet_rounded,
                              color: hasDues
                                  ? Colors.red.shade700
                                  : Colors.green.shade700,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Clear Pending Dues',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Settle cash ride commissions via UPI / Card',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _isProcessing
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Summary Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: hasDues ? Colors.red.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: hasDues
                          ? Colors.red.shade200
                          : Colors.green.shade200,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasDues
                                  ? 'Total Pending Dues'
                                  : 'No Pending Dues',
                              style: TextStyle(
                                fontSize: 11,
                                color: hasDues
                                    ? Colors.red.shade900
                                    : Colors.green.shade900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹ ${pendingDues.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: hasDues
                                    ? Colors.red.shade800
                                    : Colors.green.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Wallet Balance',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹ ${wallet.balance.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (showGatewayWarning) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: Color(0xFFB45309),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Online gateway keys are not active on the server yet. Please contact support if payment fails to launch.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Quick amount chips
                if (hasDues) ...[
                  const Text(
                    'Quick Select Amount',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ActionChip(
                        label: Text(
                          'Pay Full (₹${pendingDues.toStringAsFixed(2)})',
                        ),
                        backgroundColor: const Color(0xFFFEF3C7),
                        side: const BorderSide(color: AppColors.primary),
                        onPressed: () {
                          setState(() {
                            _amountController.text = pendingDues
                                .toStringAsFixed(2);
                          });
                        },
                      ),
                      if (pendingDues >= 200)
                        ActionChip(
                          label: Text(
                            'Pay Half (₹${(pendingDues / 2).ceil()})',
                          ),
                          onPressed: () {
                            setState(() {
                              _amountController.text = (pendingDues / 2)
                                  .ceil()
                                  .toStringAsFixed(2);
                            });
                          },
                        ),
                      if (minToUnblock >= 1 && minToUnblock < pendingDues)
                        ActionChip(
                          label: Text(
                            'Min to Unblock (₹${minToUnblock.toStringAsFixed(0)})',
                          ),
                          onPressed: () {
                            setState(() {
                              _amountController.text = minToUnblock
                                  .toStringAsFixed(2);
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],

                TextField(
                  controller: _amountController,
                  enabled: !_isProcessing,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  decoration: InputDecoration(
                    labelText: hasDues
                        ? 'Amount to Pay (INR)'
                        : 'Wallet Recharge Amount (INR)',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                ),
                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: (_isProcessing || walletState.isDuesPaying)
                        ? null
                        : () => _startDuesPayment(wallet),
                    icon: (_isProcessing || walletState.isDuesPaying)
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.payment_rounded, size: 18),
                    label: Text(
                      (_isProcessing || walletState.isDuesPaying)
                          ? 'PROCESSING PAYMENT...'
                          : (hasDues
                                ? 'PAY DUES VIA RAZORPAY'
                                : 'ADD MONEY VIA RAZORPAY'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
