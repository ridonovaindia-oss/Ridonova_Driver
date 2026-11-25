import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/network/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_flushbar.dart';
import '../auth_provider.dart';

/// 2-step Gmail OTP verification bottom sheet for Drivers.
/// Calls POST /api/driver/email/send-otp and POST /api/driver/email/verify-otp.
class GmailVerificationSheet extends ConsumerStatefulWidget {
  final String initialEmail;

  const GmailVerificationSheet({super.key, this.initialEmail = ''});

  static Future<String?> show(BuildContext context, {String initialEmail = ''}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => GmailVerificationSheet(initialEmail: initialEmail),
    );
  }

  @override
  ConsumerState<GmailVerificationSheet> createState() => _GmailVerificationSheetState();
}

class _GmailVerificationSheetState extends ConsumerState<GmailVerificationSheet> {
  final ApiService _apiService = ApiService();
  late final TextEditingController _emailController;
  final TextEditingController _otpController = TextEditingController();

  bool _isSending = false;
  bool _isVerifying = false;
  String? _changeToken;
  String? _errorText;

  static final RegExp _gmailRegex = RegExp(r'^[^\s@]+@(gmail\.com|googlemail\.com)$', caseSensitive: false);

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim().toLowerCase();
    if (!_gmailRegex.hasMatch(email)) {
      setState(() => _errorText = 'Please enter a valid @gmail.com address.');
      return;
    }

    setState(() {
      _isSending = true;
      _errorText = null;
    });

    final token = ref.read(authProvider).authToken;
    final resp = await _apiService.post(
      ApiConstants.driverEmailSendOtp,
      data: {'email': email, 'newEmail': email},
      token: token,
    );

    if (!mounted) return;
    setState(() => _isSending = false);

    if (resp.isSuccess && resp.data != null) {
      final raw = resp.data is String ? jsonDecode(resp.data) : resp.data;
      final data = raw is Map ? (raw['data'] ?? raw) : {};
      final changeToken = data is Map ? (data['changeToken']?.toString() ?? '') : '';
      if (changeToken.isNotEmpty) {
        setState(() => _changeToken = changeToken);
        AppFlushbar.success(
          context,
          title: 'OTP Sent!',
          message: 'Check $email for your 6-digit verification OTP.',
        );
        return;
      }
    }

    setState(() => _errorText = resp.errorMessage ?? 'Could not send Gmail OTP. Please try again.');
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _errorText = 'Please enter the 6-digit OTP sent to your Gmail.');
      return;
    }
    if (_changeToken == null || _changeToken!.isEmpty) return;

    setState(() {
      _isVerifying = true;
      _errorText = null;
    });

    final token = ref.read(authProvider).authToken;
    final resp = await _apiService.post(
      ApiConstants.driverEmailVerifyOtp,
      data: {'changeToken': _changeToken, 'otp': otp},
      token: token,
    );

    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (resp.isSuccess) {
      final verifiedEmail = _emailController.text.trim().toLowerCase();
      AppFlushbar.success(
        context,
        title: 'Gmail Verified ✅',
        message: '$verifiedEmail is now verified on your captain account.',
      );
      Navigator.pop(context, verifiedEmail);
    } else {
      setState(() => _errorText = resp.errorMessage ?? 'Invalid OTP. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final otpSent = _changeToken != null && _changeToken!.isNotEmpty;

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Verify Driver Gmail',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Enter your active @gmail.com address. We will send a 6-digit OTP to verify ownership.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              enabled: !otpSent,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Gmail Address',
                hintText: 'captain@gmail.com',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (otpSent) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: '6-Digit Gmail OTP',
                  hintText: 'Enter 6-digit code',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorText!,
                style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: (_isSending || _isVerifying)
                    ? null
                    : (otpSent ? _verifyOtp : _sendOtp),
                child: (_isSending || _isVerifying)
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        otpSent ? 'VERIFY GMAIL OTP' : 'SEND VERIFICATION OTP',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
              ),
            ),
            if (otpSent) ...[
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: _isSending ? null : _sendOtp,
                  child: const Text('Resend OTP'),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
