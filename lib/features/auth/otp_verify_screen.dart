import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_flushbar.dart';
import '../home/screens/main_navigation_screen.dart';
import '../kyc/kyc_details_screen.dart';
import '../kyc/kyc_provider.dart';
import '../vehicle/vehicle_details_screen.dart';
import '../vehicle/vehicle_provider.dart';
import 'auth_provider.dart';

class OtpVerifyScreen extends ConsumerStatefulWidget {
  const OtpVerifyScreen({super.key});

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  String _formatCountdown(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _onVerify() async {
    final authState = ref.read(authProvider);
    if (authState.isBlocked) {
      AppFlushbar.warning(
        context,
        title: 'Account Locked',
        message:
            'Account is temporarily locked. Please wait until the timer finishes.',
      );
      return;
    }

    FocusScope.of(context).unfocus();
    final otp = _pinController.text.trim();
    final authNotifier = ref.read(authProvider.notifier);
    authNotifier.setOtp(otp);

    final success = await authNotifier.verifyOtp();
    if (success && mounted) {
      final updatedAuthState = ref.read(authProvider);
      final bool isNewUser = updatedAuthState.user?.isNewUser ?? false;

      // Ensure fresh profile, KYC, and vehicle records are loaded
      await authNotifier.fetchProfile();
      if (!mounted) return;

      AppFlushbar.success(
        context,
        title: 'OTP Verified',
        message: 'Welcome to Ridonova Captain!',
      );

      // Step 4: Login Post-Verification Routing Logic
      // Existing driver -> Live Driver Dashboard (MainNavigationScreen)
      // New driver -> KYC Document Screen or Vehicle Details Screen
      Widget nextScreen;
      if (isNewUser) {
        final kyc = ref.read(kycProvider).kycData;
        final vehicle = ref.read(vehicleProvider).vehicleData;
        if (kyc.drivingLicenseNumber.isNotEmpty &&
            vehicle.registrationNumber.isEmpty) {
          nextScreen = const VehicleDetailsScreen();
        } else {
          nextScreen = const KycDetailsScreen();
        }
      } else {
        nextScreen = const MainNavigationScreen();
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => nextScreen),
        (route) => false,
      );
    } else if (mounted) {
      final latestState = ref.read(authProvider);
      final err =
          latestState.errorMessage ??
          'Invalid OTP code. Please enter valid code.';
      AppFlushbar.error(context, title: 'Verification Failed', message: err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Custom Pinput themes
    final defaultPinTheme = PinTheme(
      width: 48,
      height: 56,
      textStyle: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: AppColors.primary, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 8,
          ),
        ],
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
    );

    final disabledPinTheme = defaultPinTheme.copyWith(
      textStyle: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Color(0xFF94A3B8),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppColors.secondary,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('OTP Verification'),
          backgroundColor: AppColors.secondary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 20.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Icon Badge Header
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.phonelink_ring_rounded,
                      color: AppColors.primary,
                      size: 42,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                const Center(
                  child: Text(
                    'Verify Your Mobile Number',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Phone number badge with edit chip
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Code sent to ',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '+91 ${authState.phoneNumber}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Step 3 Lockout Red Alert Box when blocked
                if (authState.isBlocked) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFCA5A5),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.lock_clock_rounded,
                                color: AppColors.error,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Account Temporarily Locked',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Account is temporarily locked for 10 minutes due to 3 incorrect attempts.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF7F1D1D),
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.timer_outlined,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Unlock in ${_formatCountdown(authState.lockoutSecondsRemaining)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else if (authState.attemptsLeft < 3) ...[
                  // Remaining attempts alert
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFDE68A),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFD97706),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Incorrect OTP. ${authState.attemptsLeft} attempt${authState.attemptsLeft == 1 ? '' : 's'} remaining before 10-minute lockout.',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Pinput 6-digit PIN Widget
                Center(
                  child: Pinput(
                    length: 6,
                    controller: _pinController,
                    focusNode: _pinFocusNode,
                    enabled:
                        !authState.isBlocked &&
                        authState.status != AuthStatus.loading,
                    defaultPinTheme: authState.isBlocked
                        ? disabledPinTheme
                        : defaultPinTheme,
                    focusedPinTheme: authState.isBlocked
                        ? disabledPinTheme
                        : focusedPinTheme,
                    submittedPinTheme: authState.isBlocked
                        ? disabledPinTheme
                        : submittedPinTheme,
                    showCursor: !authState.isBlocked,
                    onChanged: (value) {
                      ref.read(authProvider.notifier).setOtp(value);
                    },
                    onCompleted: (pin) {
                      if (!authState.isBlocked) {
                        _onVerify();
                      }
                    },
                  ),
                ),

                if (!authState.isBlocked &&
                    authState.status == AuthStatus.error &&
                    authState.errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Center(
                    child: Text(
                      authState.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Resend Code 30-Second Cooldown & Lockout Check
                Center(
                  child: authState.isBlocked
                      ? const Text(
                          'OTP requests disabled while account is locked',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : (authState.resendCooldown > 0
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.timer_outlined,
                                    size: 16,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Resend code in 00:${authState.resendCooldown.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    "Didn't receive code? ",
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () async {
                                      final success = await ref
                                          .read(authProvider.notifier)
                                          .resendOtp();
                                      if (context.mounted) {
                                        if (success) {
                                          AppFlushbar.info(
                                            context,
                                            title: 'OTP Resent',
                                            message:
                                                'A new verification code has been sent.',
                                          );
                                        } else {
                                          final err = ref
                                              .read(authProvider)
                                              .errorMessage;
                                          if (err != null) {
                                            AppFlushbar.error(
                                              context,
                                              title: 'Resend Failed',
                                              message: err,
                                            );
                                          }
                                        }
                                      }
                                    },
                                    child: const Text(
                                      'Resend OTP',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              )),
                ),

                const SizedBox(height: 48),

                // Verify Primary Button
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: authState.isBlocked
                        ? []
                        : [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed:
                          (authState.isBlocked ||
                              authState.status == AuthStatus.loading)
                          ? null
                          : _onVerify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: authState.isBlocked
                            ? const Color(0xFFCBD5E1)
                            : AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFCBD5E1),
                        disabledForegroundColor: Colors.white70,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: authState.status == AuthStatus.loading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  authState.isBlocked
                                      ? 'TEMPORARILY LOCKED (${_formatCountdown(authState.lockoutSecondsRemaining)})'
                                      : 'VERIFY & CONTINUE',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  authState.isBlocked
                                      ? Icons.lock_outline_rounded
                                      : Icons.check_circle_outline_rounded,
                                  size: 20,
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
