import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/utils/app_image_utils.dart';
import '../../../auth/auth_provider.dart';
import '../../../auth/phone_login_screen.dart';
import '../../../auth/widgets/gmail_verification_dialog.dart';
import '../../../emergency/emergency_contacts_provider.dart';
import '../../../emergency/screens/driver_emergency_contacts_screen.dart';
import '../../../kyc/kyc_provider.dart';
import '../../../vehicle/vehicle_provider.dart';
import '../../../rides/ride_provider.dart';
import '../../../support/support_tickets_screen.dart';
import '../../../lost_items/presentation/driver_lost_items_screen.dart';
import '../../../lost_items/providers/driver_lost_item_provider.dart';
import '../../../wallet/wallet_provider.dart';
import '../../../wallet/presentation/widgets/bank_details_sheet.dart';

class DriverProfileTab extends ConsumerStatefulWidget {
  const DriverProfileTab({super.key});

  @override
  ConsumerState<DriverProfileTab> createState() => _DriverProfileTabState();
}

class _DriverProfileTabState extends ConsumerState<DriverProfileTab> {
  @override
  void initState() {
    super.initState();
    // Fetch latest profile & wallet dynamically from server on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshProfileData();
    });
  }

  Future<void> _refreshProfileData() async {
    await Future.wait([
      ref.read(authProvider.notifier).fetchProfile(),
      ref.read(walletProvider.notifier).fetchWalletEarnings(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final kycState = ref.watch(kycProvider);
    final vehicleState = ref.watch(vehicleProvider);
    final authState = ref.watch(authProvider);
    final walletState = ref.watch(walletProvider);
    final emergencyState = ref.watch(emergencyContactsProvider);
    final lostItemState = ref.watch(driverLostItemProvider);

    final kyc = kycState.kycData;
    final vehicle = vehicleState.vehicleData;
    final user = authState.user;

    final displayName =
        (user?.fullName != null && user!.fullName!.trim().isNotEmpty)
            ? user.fullName!.trim()
            : (kyc.fullName.isNotEmpty
                ? kyc.fullName
                : (kyc.bankAccountName.isNotEmpty
                    ? kyc.bankAccountName
                    : 'Captain Partner'));
    final displayPhone = (user?.phone.isNotEmpty == true)
        ? user!.phone
        : (kyc.mobileNumber.isNotEmpty ? kyc.mobileNumber : authState.phoneNumber);
    final countryCode = (user?.countryCode.isNotEmpty == true) ? user!.countryCode : '+91';
    final displayEmail = (user?.email != null && user!.email!.trim().isNotEmpty)
        ? user.email!.trim()
        : kyc.email;
    final profilePhotoUrl = (user?.profilePhoto != null && user!.profilePhoto!.trim().isNotEmpty)
        ? user.profilePhoto!.trim()
        : kyc.profilePhoto;

    // Dynamic KYC verification badge
    final String kycBadgeText;
    final Color kycBadgeColor;
    final IconData kycBadgeIcon;
    if (kyc.isKycApproved) {
      kycBadgeText = 'VERIFIED CAPTAIN';
      kycBadgeColor = AppColors.success;
      kycBadgeIcon = Icons.verified;
    } else if (kyc.isKycRejected) {
      kycBadgeText = 'KYC REJECTED';
      kycBadgeColor = AppColors.error;
      kycBadgeIcon = Icons.cancel_rounded;
    } else if (kyc.hasDriverProfile) {
      kycBadgeText = kyc.kycStatus.isNotEmpty
          ? 'KYC ${kyc.kycStatus.toUpperCase()}'
          : 'KYC PENDING';
      kycBadgeColor = Colors.orange;
      kycBadgeIcon = Icons.hourglass_top_rounded;
    } else {
      kycBadgeText = 'PROFILE INCOMPLETE';
      kycBadgeColor = Colors.orange;
      kycBadgeIcon = Icons.info_outline_rounded;
    }

    // Dynamic vehicle status badge
    final String vehicleBadgeText;
    final Color vehicleBadgeColor;
    if (!vehicle.hasVehicle) {
      vehicleBadgeText = 'NOT ADDED';
      vehicleBadgeColor = AppColors.textSecondary;
    } else if (vehicle.isApproved) {
      vehicleBadgeText = vehicle.status.isNotEmpty ? vehicle.status.toUpperCase() : 'APPROVED';
      vehicleBadgeColor = AppColors.success;
    } else if (vehicle.isRejected) {
      vehicleBadgeText = 'REJECTED';
      vehicleBadgeColor = AppColors.error;
    } else if (vehicle.status.isNotEmpty) {
      vehicleBadgeText = vehicle.status.toUpperCase();
      vehicleBadgeColor = Colors.orange;
    } else {
      vehicleBadgeText = 'ACTIVE';
      vehicleBadgeColor = AppColors.success;
    }

    // Dynamic bank subtitle (prefer wallet bank details, fallback to GET /driver/profile driver bank fields)
    final walletBank = walletState.wallet.bankDetails;
    final bool hasBankOrUpi =
        walletBank.isBankLinked || walletBank.isUpiLinked || kyc.maskedBankSummary.isNotEmpty;
    final String bankSubtitle = walletBank.isBankLinked
        ? '${walletBank.bankDestinationLabel} • Tap to edit'
        : (walletBank.isUpiLinked
            ? '${walletBank.upiDestinationLabel} • Tap to edit'
            : (kyc.maskedBankSummary.isNotEmpty
                ? '${kyc.maskedBankSummary} • Tap to edit'
                : 'Not Linked • Tap to add'));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Captain Profile & Vehicle'),
        backgroundColor: AppColors.secondary,
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshProfileData,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (authState.isProfileLoading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      color: AppColors.primary,
                    ),
                  ),

                if (authState.profileError != null && authState.profileError!.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            authState.profileError!,
                            style: const TextStyle(fontSize: 12, color: AppColors.error),
                          ),
                        ),
                        TextButton(
                          onPressed: _refreshProfileData,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Retry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),

                // 1. Driver Profile Hero Header Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: AppImageUtils.buildAvatarImage(
                          source: profilePhotoUrl,
                          size: 64,
                          iconSize: 38,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              displayPhone.isNotEmpty
                                  ? '$countryCode $displayPhone'
                                  : 'Phone not available',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (displayEmail.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      displayEmail,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    authState.user?.isEmailVerified == true
                                        ? Icons.verified_rounded
                                        : Icons.error_outline_rounded,
                                    size: 14,
                                    color: authState.user?.isEmailVerified == true
                                        ? AppColors.success
                                        : Colors.orange,
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: kycBadgeColor.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        kycBadgeIcon,
                                        color: kycBadgeColor,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        kycBadgeText,
                                        style: TextStyle(
                                          color: kycBadgeColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (kyc.rating != null && kyc.rating! > 0)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        color: Colors.amber,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        kyc.rating!.toStringAsFixed(1),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 2. Registered Vehicle Details Section
                const Text(
                  'My Registered Vehicle',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.local_taxi_rounded,
                                color: AppColors.primary,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vehicle.make.isNotEmpty || vehicle.model.isNotEmpty
                                        ? '${vehicle.make} ${vehicle.model}'.trim()
                                        : 'No Vehicle Registered',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    vehicle.registrationNumber.isNotEmpty
                                        ? 'Reg No: ${vehicle.registrationNumber} • ${vehicle.fuelType.toUpperCase()}'
                                        : 'Please register your vehicle',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: vehicleBadgeColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                vehicleBadgeText,
                                style: TextStyle(
                                  color: vehicleBadgeColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildDetailValue(
                              'Type',
                              vehicle.vehicleTypeName.isNotEmpty
                                  ? vehicle.vehicleTypeName
                                  : 'N/A',
                            ),
                            _buildDetailValue(
                              'Year',
                              vehicle.hasVehicle && vehicle.year > 0
                                  ? '${vehicle.year}'
                                  : 'N/A',
                            ),
                            _buildDetailValue(
                              'Color',
                              vehicle.color.isNotEmpty ? vehicle.color : 'N/A',
                            ),
                            if (vehicle.baseFare != null && vehicle.perKmRate != null)
                              _buildDetailValue(
                                'Fare',
                                '₹${vehicle.baseFare!.toStringAsFixed(0)} + ₹${vehicle.perKmRate!.toStringAsFixed(0)}/km',
                              )
                            else
                              _buildDetailValue(
                                'Insurance',
                                vehicle.insuranceExpiry.isNotEmpty
                                    ? vehicle.insuranceExpiry
                                    : 'N/A',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 3. KYC Verification Status
                const Text(
                  'KYC & Document Verification',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildKycDocRow(
                          title: 'Aadhar Card',
                          subtitle: kyc.aadharNumber.isNotEmpty
                              ? (kyc.aadharNumber.length > 4
                                    ? 'XXXX-XXXX-${kyc.aadharNumber.substring(kyc.aadharNumber.length - 4)}'
                                    : kyc.aadharNumber)
                              : 'Not Provided',
                          hasValue: kyc.aadharNumber.isNotEmpty,
                          kycStatus: kyc.kycStatus,
                        ),
                        const Divider(height: 16),
                        _buildKycDocRow(
                          title: 'PAN Card',
                          subtitle: kyc.panNumber.isNotEmpty
                              ? kyc.panNumber
                              : 'Not Provided',
                          hasValue: kyc.panNumber.isNotEmpty,
                          kycStatus: kyc.kycStatus,
                        ),
                        const Divider(height: 16),
                        _buildKycDocRow(
                          title: 'Driving License',
                          subtitle: kyc.drivingLicenseNumber.isNotEmpty
                              ? (kyc.drivingLicenseExpiry.isNotEmpty
                                  ? '${kyc.drivingLicenseNumber} • Exp: ${kyc.drivingLicenseExpiry}'
                                  : kyc.drivingLicenseNumber)
                              : 'Not Provided',
                          hasValue: kyc.drivingLicenseNumber.isNotEmpty,
                          kycStatus: kyc.kycStatus,
                        ),
                        const Divider(height: 16),
                        _buildKycDocRow(
                          title: 'Bank Account & UPI',
                          subtitle: bankSubtitle,
                          hasValue: hasBankOrUpi,
                          kycStatus: hasBankOrUpi ? 'verified' : '',
                          onTap: () => BankDetailsSheet.show(
                            context,
                            walletBank,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // 4. Safety & Emergency Contacts
              const Text(
                'Safety & Emergency',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),

              Card(
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: AppColors.error,
                      size: 22,
                    ),
                  ),
                  title: const Text(
                    'Emergency Contacts & SOS',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${emergencyState.contacts.length} of ${emergencyState.maxAllowed} contacts added • 24x7 SOS active',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DriverEmergencyContactsScreen(),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // 5. Quick Support & Account Settings
              const Text(
                'Account Settings & Help',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),

              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.account_balance_rounded,
                        color: AppColors.secondary,
                      ),
                      title: const Text(
                        'Bank Account & UPI Details',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        hasBankOrUpi ? '$bankSubtitle • Tap to change' : 'Add bank account or UPI for payouts',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                      trailing: const Icon(
                        Icons.edit_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      onTap: () async {
                        await BankDetailsSheet.show(context, walletBank);
                        if (mounted) _refreshProfileData();
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        authState.user?.isEmailVerified == true
                            ? Icons.mark_email_read_rounded
                            : Icons.mark_email_unread_rounded,
                        color: authState.user?.isEmailVerified == true
                            ? AppColors.success
                            : Colors.orange,
                      ),
                      title: const Text(
                        'Driver Gmail Verification',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        authState.user?.isEmailVerified == true
                            ? '$displayEmail (Verified)'
                            : (displayEmail.isNotEmpty
                                ? '$displayEmail (Not verified — Tap to verify)'
                                : 'Verify your @gmail.com address'),
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                      ),
                      onTap: () async {
                        final verified = await GmailVerificationSheet.show(
                          context,
                          initialEmail: displayEmail,
                        );
                        if (verified != null && mounted) {
                          await _refreshProfileData();
                        }
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.headset_mic_rounded,
                        color: AppColors.secondary,
                      ),
                      title: const Text(
                        '24x7 Captain Support',
                        style: TextStyle(fontSize: 14),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SupportTicketsScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.find_in_page_rounded,
                          color: Color(0xFFD97706),
                          size: 20,
                        ),
                      ),
                      title: const Text(
                        'Lost & Found Inquiries',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        lostItemState.pendingCount > 0
                            ? '${lostItemState.pendingCount} pending inquiry from passenger'
                            : 'Check reported items from past rides',
                        style: TextStyle(
                          fontSize: 12,
                          color: lostItemState.pendingCount > 0
                              ? Colors.orange.shade900
                              : AppColors.textSecondary,
                          fontWeight: lostItemState.pendingCount > 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (lostItemState.pendingCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${lostItemState.pendingCount} NEW',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DriverLostItemsScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.privacy_tip_rounded,
                        color: AppColors.secondary,
                      ),
                      title: const Text(
                        'Privacy Policy',
                        style: TextStyle(fontSize: 14),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                      ),
                      onTap: () {
                        _showPrivacyPolicyDialog(context);
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.delete_forever_rounded,
                        color: AppColors.error,
                      ),
                      title: const Text(
                        'Delete Account',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                      ),
                      onTap: () {
                        _showDeleteAccountBottomSheet(context, ref);
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.logout_rounded,
                        color: AppColors.error,
                      ),
                      title: const Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (dialogContext) {
                            bool isLoggingOut = false;
                            return StatefulBuilder(
                              builder: (context, setDialogState) {
                                return AlertDialog(
                                  title: const Text('Logout?'),
                                  content: const Text(
                                    'Are you sure you want to logout? You will be set offline and all active processes will be closed.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: isLoggingOut
                                          ? null
                                          : () => Navigator.pop(dialogContext),
                                      child: const Text('CANCEL'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.error,
                                      ),
                                      onPressed: isLoggingOut
                                          ? null
                                          : () async {
                                              setDialogState(() {
                                                isLoggingOut = true;
                                              });

                                              // 1. Go offline and stop all timers/processes in ride provider
                                              await ref
                                                  .read(rideProvider.notifier)
                                                  .goOffline();

                                              // 2. Call auth logout & clear session
                                              await ref
                                                  .read(authProvider.notifier)
                                                  .logout();

                                              // 3. Clear duty status in SharedPreferences explicitly
                                              try {
                                                final prefs =
                                                    await SharedPreferences.getInstance();
                                                await prefs.setBool(
                                                  'is_duty_online',
                                                  false,
                                                );
                                                await prefs.remove(
                                                  'is_duty_online',
                                                );
                                              } catch (_) {}

                                              if (context.mounted) {
                                                Navigator.pop(dialogContext);
                                                AppFlushbar.success(
                                                  context,
                                                  title: 'Logged Out 🔴',
                                                  message:
                                                      'You have been logged out successfully.',
                                                );
                                                Navigator.pushAndRemoveUntil(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        const PhoneLoginScreen(),
                                                  ),
                                                  (route) => false,
                                                );
                                              }
                                            },
                                      child: isLoggingOut
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text('YES, LOGOUT'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildKycDocRow({
    required String title,
    required String subtitle,
    required bool hasValue,
    String kycStatus = '',
    VoidCallback? onTap,
  }) {
    final normalizedStatus = kycStatus.toLowerCase().trim();
    final bool isApproved =
        hasValue && (normalizedStatus == 'approved' || normalizedStatus == 'verified');
    final bool isRejected = hasValue && normalizedStatus == 'rejected';

    Widget trailing;
    if (isApproved) {
      trailing = const Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.success, size: 16),
          SizedBox(width: 4),
          Text(
            'Verified',
            style: TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      );
    } else if (isRejected) {
      trailing = const Row(
        children: [
          Icon(Icons.cancel_rounded, color: AppColors.error, size: 16),
          SizedBox(width: 4),
          Text(
            'Rejected',
            style: TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      );
    } else if (hasValue) {
      trailing = const Row(
        children: [
          Icon(Icons.schedule_rounded, color: Colors.orange, size: 16),
          SizedBox(width: 4),
          Text(
            'Pending',
            style: TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      );
    } else if (onTap != null) {
      trailing = const Row(
        children: [
          Text(
            'Link',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          SizedBox(width: 2),
          Icon(Icons.arrow_forward_ios_rounded, color: AppColors.primary, size: 11),
        ],
      );
    } else {
      trailing = const Text(
        'Missing',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      );
    }

    final content = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        trailing,
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: content,
        ),
      );
    }

    return content;
  }

  void _showPrivacyPolicyDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(20),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Privacy Policy - Ridonova Driver',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Effective Date: October 17, 2026',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Ridonova ("we", "our", or "us") operates the Ridonova Driver Mobile Application. This Privacy Policy informs you regarding the collection, use, and disclosure of personal data when you use our app.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          '1. Information We Collect',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '• Personal Data: Full name, phone number (7978800300), email (support@ridonova.com).\n'
                          '• KYC Documents: Aadhar, PAN, Driving License.\n'
                          '• Vehicle Information: Registration number, insurance, RC details.\n'
                          '• Precise Location: Real-time GPS location data when online on duty for ride matching, navigation, and trip tracking.\n'
                          '• Financial Information: Bank account number, IFSC code, and UPI ID for instant daily payouts.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          '2. How We Use Your Information',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'We use your data to verify KYC compliance, connect you with nearby riders, calculate earnings, process instant cashouts, and provide 24/7 support assistance.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          '3. Contact Us',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Email: support@ridonova.com\nPhone: 7978800300',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final url = Uri.parse(
                        'https://ridonova.in/privacy-policy.html',
                      );
                      if (await canLaunchUrl(url)) {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'OPEN FULL WEB PRIVACY POLICY',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteAccountBottomSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    List<Map<String, dynamic>> reasons = [];
    try {
      reasons = await ref.read(authProvider.notifier).fetchDeletionReasons();
    } catch (_) {}

    if (reasons.isEmpty) {
      reasons = [
        {"id": "low_earnings", "label": "Earnings are lower than expected"},
        {
          "id": "switching_platform",
          "label": "Switching to another platform / company",
        },
        {
          "id": "vehicle_issues",
          "label": "Vehicle sold or no longer available",
        },
        {"id": "personal_reasons", "label": "Personal or health reasons"},
        {"id": "other", "label": "Other (Please describe)"},
      ];
    }

    String selectedReasonId = reasons.first['id'];
    final feedbackController = TextEditingController();
    bool isDeleting = false;

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 20,
                  right: 20,
                  top: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.error,
                          size: 26,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Permanently Delete Account',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This action is permanent and cannot be undone. All your profile data, KYC, and earnings history will be permanently deleted.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Please select a reason for leaving:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: reasons.length,
                        itemBuilder: (context, index) {
                          final r = reasons[index];
                          return RadioListTile<String>(
                            title: Text(
                              r['label'] ?? '',
                              style: const TextStyle(fontSize: 13),
                            ),
                            value: r['id'],
                            groupValue: selectedReasonId,
                            activeColor: AppColors.error,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() {
                                  selectedReasonId = val;
                                });
                              }
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: feedbackController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Additional feedback (Optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: isDeleting
                            ? null
                            : () async {
                                setModalState(() {
                                  isDeleting = true;
                                });

                                final response = await ref
                                    .read(authProvider.notifier)
                                    .deleteAccount(
                                      reason: selectedReasonId,
                                      feedback:
                                          feedbackController.text
                                              .trim()
                                              .isNotEmpty
                                          ? feedbackController.text.trim()
                                          : null,
                                    );

                                if (!context.mounted) return;

                                if (response.isSuccess) {
                                  Navigator.pop(context); // close sheet
                                  AppFlushbar.success(
                                    context,
                                    title: 'Account Deleted 🔴',
                                    message:
                                        'Your account has been permanently deleted.',
                                  );
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const PhoneLoginScreen(),
                                    ),
                                    (route) => false,
                                  );
                                } else {
                                  setModalState(() {
                                    isDeleting = false;
                                  });
                                  Navigator.pop(context); // close sheet
                                  AppFlushbar.error(
                                    context,
                                    title: 'Deletion Failed',
                                    message:
                                        response.errorMessage ??
                                        'Could not delete account. Make sure you have no active rides.',
                                  );
                                }
                              },
                        child: isDeleting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'CONFIRM PERMANENT DELETE',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
