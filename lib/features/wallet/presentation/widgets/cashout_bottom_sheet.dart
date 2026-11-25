import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../kyc/kyc_details_screen.dart';
import '../../../kyc/kyc_provider.dart';
import '../../../support/support_tickets_screen.dart';
import '../screens/payout_history_screen.dart';
import 'bank_details_sheet.dart';
import 'pay_dues_bottom_sheet.dart';
import 'payout_receipt_modal.dart';
import '../../wallet_model.dart';
import '../../wallet_provider.dart';

class CashoutBottomSheet extends ConsumerStatefulWidget {
  const CashoutBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const CashoutBottomSheet(),
    );
  }

  @override
  ConsumerState<CashoutBottomSheet> createState() => _CashoutBottomSheetState();
}

class _CashoutBottomSheetState extends ConsumerState<CashoutBottomSheet> {
  late TextEditingController _amountController;
  String _selectedMethod = 'bank';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final wallet = ref.read(walletProvider).wallet;
    final initialAmt = wallet.availableBalance > 0
        ? wallet.availableBalance.toStringAsFixed(0)
        : wallet.payoutRules.minPayoutAmount.toStringAsFixed(0);
    _amountController = TextEditingController(text: initialAmt);

    // Pick default method based on available linked accounts
    if (wallet.bankDetails.isBankLinked) {
      _selectedMethod = 'bank';
    } else if (wallet.bankDetails.isUpiLinked) {
      _selectedMethod = 'upi';
    } else {
      _selectedMethod = wallet.bankDetails.defaultMethod;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _setAmount(double amount) {
    setState(() {
      _amountController.text = amount.toStringAsFixed(0);
    });
  }

  bool _isKycApproved(WalletModel wallet) {
    final kycData = ref.read(kycProvider).kycData;
    final kycStatus = wallet.kycStatus.isNotEmpty
        ? wallet.kycStatus
        : (kycData.kycStatus.isNotEmpty
            ? kycData.kycStatus
            : (kycData.drivingLicenseNumber.isNotEmpty ? 'approved' : 'pending'));
    return kycStatus.toLowerCase() == 'approved';
  }

  Future<void> _handleWithdraw(WalletModel wallet) async {
    if (_isSubmitting) return;

    // 1. Guard: Accounts Linked
    if (!wallet.bankDetails.isBankLinked && !wallet.bankDetails.isUpiLinked) {
      final navContext = Navigator.of(context).context;
      Navigator.pop(context);
      BankDetailsSheet.show(navContext, wallet.bankDetails);
      return;
    }

    // 2. Guard: KYC Status Check
    if (!_isKycApproved(wallet)) {
      _showSpecificErrorDialog(
        title: 'KYC Verification Required',
        message: 'Your KYC documents must be verified and approved before you can withdraw earnings.',
        actionLabel: 'VERIFY KYC',
        onAction: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const KycDetailsScreen()));
        },
      );
      return;
    }

    // 3. Guard: Negative / Blocked Balance
    if (wallet.balance <= 0 || wallet.isWalletBlocked) {
      _showSpecificErrorDialog(
        title: 'Withdrawal Blocked',
        message: 'Withdrawal is blocked due to pending cash commission dues (₹${wallet.balance.toStringAsFixed(2)}). Please clear dues to withdraw.',
        actionLabel: 'OK',
      );
      return;
    }

    // 4. Guard: Daily Limit Check
    if (wallet.payoutRules.isDailyLimitReached) {
      _showSpecificErrorDialog(
        title: 'Daily Limit Reached',
        message: 'You have reached the maximum allowed limit of ${wallet.payoutRules.maxPayoutsPerDay} payouts per day. Next withdrawal will be available tomorrow.',
        actionLabel: 'OK',
      );
      return;
    }

    // 5. Amount parsing and min/max checks
    final amt = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amt < wallet.payoutRules.minPayoutAmount) {
      AppFlushbar.error(
        context,
        title: 'Minimum Payout Required',
        message: 'Minimum withdrawal amount is ₹${wallet.payoutRules.minPayoutAmount.toStringAsFixed(2)} as per platform policy.',
      );
      return;
    }

    if (amt > wallet.availableBalance) {
      AppFlushbar.error(
        context,
        title: 'Insufficient Balance',
        message: 'Requested amount exceeds your available balance (₹${wallet.availableBalance.toStringAsFixed(2)}).',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await ref.read(walletProvider.notifier).requestPayout(
      amount: amt,
      payoutMethod: _selectedMethod,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.isSuccess) {
      // Close cashout sheet
      Navigator.pop(context);

      // Open Async State Receipt Modal
      PayoutReceiptModal.show(
        context,
        result: result,
        onViewHistory: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PayoutHistoryScreen(highlightPayoutId: result.payoutId),
            ),
          );
        },
      );
    } else {
      _handlePayoutErrorCode(result);
    }
  }

  void _handlePayoutErrorCode(PayoutRequestResult result) {
    final code = (result.errorCode ?? '').toUpperCase();
    final message = result.message;

    if (code == 'KYC_NOT_VERIFIED' || result.httpStatusCode == 403 && code.contains('KYC')) {
      _showSpecificErrorDialog(
        title: 'KYC Not Verified',
        message: message.isNotEmpty ? message : 'Complete KYC to enable earning withdrawals.',
        actionLabel: 'VERIFY KYC',
        onAction: () {
          Navigator.pop(context); // close sheet
          Navigator.push(context, MaterialPageRoute(builder: (_) => const KycDetailsScreen()));
        },
      );
    } else if (code == 'ACCOUNT_SUSPENDED') {
      _showSpecificErrorDialog(
        title: 'Account Suspended',
        message: message.isNotEmpty ? message : 'Your driver account has been suspended. Please contact Ridonova Support.',
        actionLabel: 'CONTACT SUPPORT',
        onAction: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportTicketsScreen()));
        },
      );
    } else if (code == 'BANK_DETAILS_MISSING') {
      _showSpecificErrorDialog(
        title: 'Bank Details Missing',
        message: message.isNotEmpty ? message : 'Please link your Bank Account or UPI to initiate withdrawal.',
        actionLabel: 'LINK ACCOUNT',
        onAction: () {
          final navContext = Navigator.of(context).context;
          Navigator.pop(context);
          BankDetailsSheet.show(navContext, ref.read(walletProvider).wallet.bankDetails);
        },
      );
    } else if (code == 'DAILY_LIMIT_REACHED') {
      _showSpecificErrorDialog(
        title: 'Daily Limit Reached',
        message: 'Max 2 payouts per day allowed. Daily limit reached, available tomorrow.',
        actionLabel: 'OK',
      );
    } else if (code == 'BELOW_MIN_PAYOUT') {
      AppFlushbar.error(
        context,
        title: 'Minimum Payout Error',
        message: message.isNotEmpty ? message : 'Minimum withdrawal amount is ₹100.',
      );
    } else if (code == 'INSUFFICIENT_OR_BLOCKED_BALANCE') {
      _showSpecificErrorDialog(
        title: 'Insufficient / Blocked Balance',
        message: message.isNotEmpty ? message : 'Withdrawal blocked due to pending cash commission dues. Clear dues to withdraw.',
        actionLabel: 'OK',
      );
    } else {
      AppFlushbar.error(
        context,
        title: 'Cashout Failed',
        message: message.isNotEmpty ? message : 'Could not process payout. Please try again.',
      );
    }
  }

  void _showSpecificErrorDialog({
    required String title,
    required String message,
    required String actionLabel,
    VoidCallback? onAction,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            const SizedBox(width: 8),
            Flexible(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              if (onAction != null) onAction();
            },
            child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    final wallet = walletState.wallet;
    final isKycOk = _isKycApproved(wallet);
    final isDailyLimitReached = wallet.payoutRules.isDailyLimitReached;
    final isNegativeOrBlocked = wallet.balance <= 0 || wallet.isWalletBlocked;
    final hasNoAccount = !wallet.bankDetails.isBankLinked && !wallet.bankDetails.isUpiLinked;

    final bool canWithdraw = isKycOk &&
        !isDailyLimitReached &&
        !isNegativeOrBlocked &&
        !hasNoAccount &&
        !_isSubmitting &&
        !walletState.isPayoutLoading;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Text(
                      'Instant Cashout to Bank',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.flash_on_rounded, color: AppColors.primary, size: 20),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 1. Guard Banner: KYC Pending
            if (!isKycOk)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_outlined, color: Color(0xFFB45309), size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Complete KYC to enable earning withdrawals.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFB45309),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const KycDetailsScreen()));
                      },
                      child: const Text('Verify KYC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

            // 2. Guard Banner: Negative Commission Dues
            if (isNegativeOrBlocked)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.block_rounded, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Withdrawal blocked due to pending cash commission dues. Clear dues to withdraw.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade900),
                      ),
                    ),
                  ],
                ),
              ),

            // 3. Guard Banner: Daily Limit Reached
            if (!isNegativeOrBlocked && isDailyLimitReached)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time_rounded, color: Colors.orange.shade800, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Daily limit reached (${wallet.payoutRules.maxPayoutsPerDay}/${wallet.payoutRules.maxPayoutsPerDay} today). Available tomorrow.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                      ),
                    ),
                  ],
                ),
              ),

            // 4. Guard Banner: No Account Linked
            if (hasNoAccount)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add_card_rounded, color: Color(0xFF1D4ED8), size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Add Bank Account or UPI to Withdraw earnings.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        final navContext = Navigator.of(context).context;
                        Navigator.pop(context);
                        BankDetailsSheet.show(navContext, wallet.bankDetails);
                      },
                      child: const Text('Add Account', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

            // Destination Account Selection
            if (!hasNoAccount) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Withdraw To Destination:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 14),
                    label: const Text('Change Account', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      final navContext = Navigator.of(context).context;
                      Navigator.pop(context);
                      BankDetailsSheet.show(navContext, wallet.bankDetails);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (wallet.bankDetails.isBankLinked)
                InkWell(
                  onTap: () => setState(() => _selectedMethod = 'bank'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: _selectedMethod == 'bank' ? const Color(0xFFEFF6FF) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedMethod == 'bank' ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
                        width: _selectedMethod == 'bank' ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedMethod == 'bank' ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: _selectedMethod == 'bank' ? AppColors.primary : Colors.grey,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.account_balance_outlined, size: 18, color: AppColors.secondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            wallet.bankDetails.bankDestinationLabel,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (wallet.bankDetails.isUpiLinked)
                InkWell(
                  onTap: () => setState(() => _selectedMethod = 'upi'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: _selectedMethod == 'upi' ? const Color(0xFFEFF6FF) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedMethod == 'upi' ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
                        width: _selectedMethod == 'upi' ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedMethod == 'upi' ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: _selectedMethod == 'upi' ? AppColors.primary : Colors.grey,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.flash_on_rounded, size: 18, color: Color(0xFF0284C7)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            wallet.bankDetails.upiDestinationLabel,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
            ],

            // Amount Input Field
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: 'Withdrawal Amount (₹) *',
                prefixText: '₹ ',
                prefixStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () => _amountController.clear(),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Quick Amount Chips
            Wrap(
              spacing: 8,
              children: [
                _buildQuickChip('₹ 100', () => _setAmount(100)),
                _buildQuickChip('₹ 500', () => _setAmount(500)),
                _buildQuickChip('₹ 1000', () => _setAmount(1000)),
                if (wallet.availableBalance > 0)
                  _buildQuickChip(
                    'Full (₹${wallet.availableBalance.toStringAsFixed(0)})',
                    () => _setAmount(wallet.availableBalance),
                    isHighlighted: true,
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Payout Rules Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildRuleRow(
                    'Minimum Payout:',
                    '₹ ${wallet.payoutRules.minPayoutAmount.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 5),
                  _buildRuleRow(
                    'Instant Cashout Fee:',
                    '₹ ${wallet.payoutRules.instantCashoutFee.toStringAsFixed(2)} (Zero Fee)',
                    isSuccess: true,
                  ),
                  const SizedBox(height: 5),
                  _buildRuleRow(
                    'Payouts Left Today:',
                    '${wallet.payoutRules.payoutsRemainingToday} of ${wallet.payoutRules.maxPayoutsPerDay}',
                    isWarning: wallet.payoutRules.isDailyLimitReached,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Withdraw Button with Double-Tap Lock
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: (isNegativeOrBlocked && wallet.balance < 0) ? Colors.red.shade700 : AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: canWithdraw
                    ? () => _handleWithdraw(wallet)
                    : ((isNegativeOrBlocked && wallet.balance < 0)
                        ? () {
                            final navContext = Navigator.of(context).context;
                            Navigator.pop(context);
                            PayDuesBottomSheet.show(navContext);
                          }
                        : null),
                icon: (_isSubmitting || walletState.isPayoutLoading)
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon((isNegativeOrBlocked && wallet.balance < 0) ? Icons.payment_rounded : Icons.flash_on_rounded, size: 18),
                label: Text(
                  (_isSubmitting || walletState.isPayoutLoading)
                      ? 'PROCESSING WITHDRAWAL...'
                      : (!isKycOk
                          ? 'COMPLETE KYC TO WITHDRAW'
                          : isDailyLimitReached
                              ? 'DAILY LIMIT REACHED (2/2)'
                              : (isNegativeOrBlocked && wallet.balance < 0)
                                  ? 'PAY DUES NOW (₹${wallet.effectivePendingDues.toStringAsFixed(2)})'
                                  : isNegativeOrBlocked
                                      ? 'NO BALANCE TO WITHDRAW'
                                      : hasNoAccount
                                          ? 'ADD BANK OR UPI TO WITHDRAW'
                                          : 'CONFIRM & WITHDRAW'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, VoidCallback onTap, {bool isHighlighted = false}) {
    return ActionChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.bold,
        color: isHighlighted ? AppColors.primaryDark : AppColors.textPrimary,
      ),
      backgroundColor: isHighlighted ? const Color(0xFFFEF3C7) : Colors.white,
      side: BorderSide(color: isHighlighted ? AppColors.primary : Colors.grey.shade300),
      onPressed: onTap,
    );
  }

  Widget _buildRuleRow(String label, String value, {bool isSuccess = false, bool isWarning = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSuccess
                ? AppColors.success
                : isWarning
                    ? Colors.orange.shade800
                    : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
