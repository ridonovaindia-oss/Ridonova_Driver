import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../wallet_model.dart';
import '../../wallet_provider.dart';

class BankDetailsSheet extends ConsumerStatefulWidget {
  final BankDetailsModel bankDetails;

  const BankDetailsSheet({super.key, required this.bankDetails});

  static Future<void> show(BuildContext context, BankDetailsModel bankDetails) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => BankDetailsSheet(bankDetails: bankDetails),
    );
  }

  @override
  ConsumerState<BankDetailsSheet> createState() => _BankDetailsSheetState();
}

class _BankDetailsSheetState extends ConsumerState<BankDetailsSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _holderController;
  late TextEditingController _accountController;
  late TextEditingController _confirmAccountController;
  late TextEditingController _ifscController;
  late TextEditingController _bankNameController;
  late TextEditingController _upiController;

  late String _defaultMethod;
  bool _isEditing = false;
  bool _obscureAccount = true;

  // Strict Production-Ready Validation Regexes as specified:
  // accountHolder: 2 to 100 letters (/^[A-Za-z][A-Za-z\s.'-]{1,99}$/)
  static final RegExp _holderRegex = RegExp(r"^[A-Za-z][A-Za-z\s.'-]{1,99}$");
  // accountNumber: 9 to 18 digits (/^\d{9,18}$/)
  static final RegExp _accountRegex = RegExp(r"^\d{9,18}$");
  // ifscCode: 11 alphanumeric (/^[A-Z]{4}0[A-Z0-9]{6}$/)
  static final RegExp _ifscRegex = RegExp(r"^[A-Z]{4}0[A-Z0-9]{6}$");
  // upiId: Valid VPA pattern (/^[a-zA-Z0-9._-]{2,256}@[a-zA-Z]{2,64}$/)
  static final RegExp _upiRegex = RegExp(r"^[a-zA-Z0-9._-]{2,256}@[a-zA-Z]{2,64}$");

  @override
  void initState() {
    super.initState();
    final d = widget.bankDetails;
    _holderController = TextEditingController(text: d.accountHolder);
    _accountController = TextEditingController();
    _confirmAccountController = TextEditingController();
    _ifscController = TextEditingController(text: d.ifscCode);
    _bankNameController = TextEditingController(text: d.bankName);
    _upiController = TextEditingController(text: d.upiId);
    _defaultMethod = d.defaultMethod.isNotEmpty ? d.defaultMethod : 'bank';

    // If no account is linked yet, start in editing mode
    if (!d.isBankLinked && !d.isUpiLinked) {
      _isEditing = true;
    }
  }

  @override
  void dispose() {
    _holderController.dispose();
    _accountController.dispose();
    _confirmAccountController.dispose();
    _ifscController.dispose();
    _bankNameController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text, String label) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    AppFlushbar.success(context, title: 'Copied!', message: '$label copied to clipboard.');
  }

  Future<void> _submitBankDetails() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final holder = _holderController.text.trim();
    final acct = _accountController.text.trim();
    final ifsc = _ifscController.text.trim().toUpperCase();
    final bankName = _bankNameController.text.trim();
    final upi = _upiController.text.trim();

    final response = await ref.read(walletProvider.notifier).updateBankDetails(
      accountHolder: holder,
      accountNumber: acct,
      ifscCode: ifsc,
      bankName: bankName,
      upiId: upi,
      defaultMethod: _defaultMethod,
    );

    if (!mounted) return;

    if (response.isSuccess) {
      AppFlushbar.success(
        context,
        title: 'Bank & UPI Details Saved! ✅',
        message: 'Your payout destinations have been updated securely.',
      );
      setState(() {
        _isEditing = false;
        _accountController.clear();
        _confirmAccountController.clear();
      });
      Navigator.pop(context);
    } else {
      AppFlushbar.error(
        context,
        title: 'Update Failed',
        message: response.errorMessage ?? 'Failed to update bank details.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    final bankDetails = walletState.wallet.bankDetails;

    return Padding(
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
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_balance_rounded, color: AppColors.secondary, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bank & UPI Management',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          'Dedicated payout destinations',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Linked Status Chips (Wrap prevents horizontal overflow clipping Edit button!)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildStatusChip(
                  label: 'Bank Account',
                  isLinked: bankDetails.isBankLinked,
                ),
                _buildStatusChip(
                  label: 'UPI VPA',
                  isLinked: bankDetails.isUpiLinked,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Mode: Read-Only Card or Edit Form
            if (!_isEditing && (bankDetails.isBankLinked || bankDetails.isUpiLinked))
              _buildSavedDetailsCard(bankDetails)
            else
              _buildEditForm(walletState.isBankUpdating),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip({required String label, required bool isLinked}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isLinked ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isLinked ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLinked ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            color: isLinked ? const Color(0xFF15803D) : const Color(0xFFB45309),
            size: 14,
          ),
          const SizedBox(width: 5),
          Text(
            isLinked ? '$label: Linked ✅' : '$label: Not Linked ⚠️',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isLinked ? const Color(0xFF15803D) : const Color(0xFFB45309),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedDetailsCard(BankDetailsModel bankDetails) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bankDetails.isBankLinked) ...[
            const Row(
              children: [
                Icon(Icons.account_balance_outlined, size: 16, color: AppColors.secondary),
                SizedBox(width: 6),
                Text('Bank Account (Protected)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary)),
              ],
            ),
            const SizedBox(height: 10),
            _buildDetailRow(
              label: 'Account Holder',
              value: bankDetails.accountHolder.isNotEmpty ? bankDetails.accountHolder : 'Captain',
            ),
            const SizedBox(height: 6),
            _buildDetailRow(
              label: 'Account Number',
              value: bankDetails.maskedAccountNumber,
              isMonospace: true,
            ),
            const SizedBox(height: 6),
            _buildDetailRow(
              label: 'Bank Name',
              value: bankDetails.bankName.isNotEmpty ? bankDetails.bankName : 'Commercial Bank',
              copyable: true,
            ),
            const SizedBox(height: 6),
            _buildDetailRow(
              label: 'IFSC Code',
              value: bankDetails.ifscCode,
              isMonospace: true,
              copyable: true,
            ),
            const SizedBox(height: 12),
          ],
          if (bankDetails.isUpiLinked) ...[
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.flash_on_rounded, size: 16, color: Color(0xFF0284C7)),
                SizedBox(width: 6),
                Text('UPI Instant Payout', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
              ],
            ),
            const SizedBox(height: 10),
            _buildDetailRow(
              label: 'UPI ID / VPA',
              value: bankDetails.upiId,
              copyable: true,
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text(
                'CHANGE / UPDATE BANK ACCOUNT',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                  _holderController.text = bankDetails.accountHolder;
                  _ifscController.text = bankDetails.ifscCode;
                  _bankNameController.text = bankDetails.bankName;
                  _upiController.text = bankDetails.upiId;
                  _accountController.clear();
                  _confirmAccountController.clear();
                });
              },
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF16A34A)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Full account number is encrypted on server. Updating bank details does not re-trigger KYC re-verification.',
                    style: TextStyle(fontSize: 10.5, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    bool isMonospace = false,
    bool copyable = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFamily: isMonospace ? 'monospace' : null,
                color: AppColors.textPrimary,
              ),
            ),
            if (copyable && value.isNotEmpty) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: () => _copyToClipboard(value, label),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.copy_rounded, size: 14, color: AppColors.primary),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildEditForm(bool isUpdating) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Notice banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_outline_rounded, color: Color(0xFF16A34A), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bank & UPI details are stored securely for instant IMPS/UPI payouts. Validated with RazorpayX standards.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF15803D), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Account Holder Name
          TextFormField(
            controller: _holderController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Account Holder Name *',
              hintText: 'e.g. Ramesh Kumar',
              prefixIcon: const Icon(Icons.person_outline_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) {
              final val = v?.trim() ?? '';
              if (val.isEmpty) return 'Account holder name is required';
              if (!_holderRegex.hasMatch(val)) {
                return 'Enter 2-100 letters only (valid legal name)';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Account Number
          TextFormField(
            controller: _accountController,
            keyboardType: TextInputType.number,
            obscureText: _obscureAccount,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(18),
            ],
            decoration: InputDecoration(
              labelText: 'Bank Account Number *',
              hintText: '9 to 18 digits',
              prefixIcon: const Icon(Icons.account_balance_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscureAccount ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _obscureAccount = !_obscureAccount),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) {
              final val = v?.trim() ?? '';
              if (val.isEmpty) return 'Account number is required';
              if (!_accountRegex.hasMatch(val)) {
                return 'Account number must be 9 to 18 digits';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Re-enter Account Number
          TextFormField(
            controller: _confirmAccountController,
            keyboardType: TextInputType.number,
            obscureText: _obscureAccount,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(18),
            ],
            decoration: InputDecoration(
              labelText: 'Re-enter Account Number *',
              hintText: 'Confirm account number',
              prefixIcon: const Icon(Icons.check_circle_outline_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) {
              final val = v?.trim() ?? '';
              if (val.isEmpty) return 'Please re-enter account number';
              if (val != _accountController.text.trim()) {
                return 'Account numbers do not match!';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // IFSC Code (Auto-Capitalize)
          TextFormField(
            controller: _ifscController,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
              LengthLimitingTextInputFormatter(11),
              _UpperCaseTextFormatter(),
            ],
            decoration: InputDecoration(
              labelText: 'IFSC Code *',
              hintText: 'e.g. HDFC0001234',
              prefixIcon: const Icon(Icons.qr_code_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) {
              final val = v?.trim().toUpperCase() ?? '';
              if (val.isEmpty) return 'IFSC code is required';
              if (!_ifscRegex.hasMatch(val)) {
                return 'Invalid IFSC (e.g. 4 letters, 0, then 6 alphanumeric characters)';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Bank Name
          TextFormField(
            controller: _bankNameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Bank Name *',
              hintText: 'e.g. HDFC Bank, SBI, ICICI Bank',
              prefixIcon: const Icon(Icons.business_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) {
              final val = v?.trim() ?? '';
              if (val.isEmpty) return 'Bank name is required';
              if (val.length < 2) return 'Enter valid bank name';
              return null;
            },
          ),
          const SizedBox(height: 14),

          // UPI ID (Optional VPA)
          TextFormField(
            controller: _upiController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'UPI ID / VPA (Optional for Instant UPI)',
              hintText: 'e.g. ramesh@okhdfcbank, captain@upi',
              prefixIcon: const Icon(Icons.flash_on_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) {
              final val = v?.trim() ?? '';
              if (val.isNotEmpty && !_upiRegex.hasMatch(val)) {
                return 'Invalid UPI VPA (format: username@bank)';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Default Method Radio
          const Text('Preferred Payout Destination:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Row(
            children: [
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('Bank Account', style: TextStyle(fontSize: 13)),
                  value: 'bank',
                  groupValue: _defaultMethod,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primary,
                  onChanged: (val) => setState(() => _defaultMethod = val ?? 'bank'),
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('UPI ID', style: TextStyle(fontSize: 13)),
                  value: 'upi',
                  groupValue: _defaultMethod,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primary,
                  onChanged: (val) => setState(() => _defaultMethod = val ?? 'upi'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isUpdating ? null : _submitBankDetails,
              icon: isUpdating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(
                isUpdating ? 'SAVING DETAILS...' : 'SAVE BANK & UPI DETAILS',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
