class ApiConstants {
  /// Server origin from build env: flutter run --dart-define-from-file=env/dev.json
  static const String serverOrigin = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://admin.ridonova.in');
  static const String baseUrl = '$serverOrigin/api';
  static const String driverBaseUrl = '$serverOrigin/api/driver';
  static const String socketUrl = serverOrigin;
  /// Kept only so old comparisons compile; it is never sent to the server anymore.
  static const String defaultDevToken = '';

  // Auth Endpoints
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String resendOtp = '/auth/resend-otp';
  static const String refreshToken = '/auth/refresh-token';
  static const String logout = '/auth/logout';

  // Driver Profile & KYC Endpoints
  static const String driverProfile = '/driver/profile';
  static const String driverKyc = '/driver/kyc';
  static const String driverVehicle = '/driver/vehicle';
  static const String vehicleTypes = '/vehicle-types';
  static const String dutyStatus = '/driver/duty-status';
  static const String driverEmailSendOtp = '/driver/email/send-otp';
  static const String driverEmailVerifyOtp = '/driver/email/verify-otp';
  static const String changeEmailSendOtp = '/driver/change-email/send-otp';
  static const String changeEmailVerify = '/driver/change-email/verify';
  static const String changeMobileSendOtp = '/driver/change-mobile/send-otp';
  static const String changeMobileVerifyOld = '/driver/change-mobile/verify-old';
  static const String changeMobileVerifyNew = '/driver/change-mobile/verify-new';

  // Driver REST Execution APIs
  static const String goOnline = '/driver/online';
  static const String goOffline = '/driver/offline';
  static const String updateLocation = '/driver/location';
  static const String updateBattery = '/driver/battery';
  static const String getRideRequests = '/driver/ride-requests';

  static String acceptRideRequest(String rideId) => '/driver/riderequests/$rideId/accept';
  static String rejectRideRequest(String rideId) => '/driver/riderequests/$rideId/reject';
  static String getRideDetails(String rideId) => '/driver/rides/$rideId';
  static String getRideRoute(String rideId, double lat, double lng) => '/driver/rides/$rideId/route?lat=$lat&lng=$lng';
  static String arrivedAtPickup(String rideId) => '/driver/rides/$rideId/arrived';
  static String getWaitingCharges(String rideId) => '/driver/rides/$rideId/waiting';
  static String startRide(String rideId) => '/driver/rides/$rideId/start';
  static String completeRide(String rideId) => '/driver/rides/$rideId/complete';
  static String cancelRide(String rideId) => '/driver/rides/$rideId/cancel';
  static String cancelDriverRide(String rideId) => '/driver/rides/$rideId/cancel';
  static const String driverCancelReasons = '/driver/cancel-reasons';
  static String rateRider(String rideId) => '/driver/rides/$rideId/rate';

  // Navigation, Calls & Places
  static const String fetchRoute = '/places/route';
  static const String maskCall = '/call/mask-call';

  // Wallet, History & Payout
  static const String driverWallet = '/driver/wallet';
  static const String driverWalletDues = '/driver/wallet/dues';
  static const String driverWalletDuesCreateOrder = '/driver/wallet/dues/create-order';
  static const String driverWalletDuesVerify = '/driver/wallet/dues/verify';
  static const String driverWalletTransactions = '/driver/wallet/transactions';
  static const String driverPayouts = '/driver/payouts';
  static const String driverBankDetails = '/driver/bank-details';
  static const String driverRides = '/driver/rides';
  static const String payoutRequest = '/driver/payout-request';
  static String collectCash(String rideId) => '/driver/rides/$rideId/collect-cash';

  // Support & Tickets
  static const String supportCategories = '/driver/support/categories';
  static const String supportTickets = '/driver/support/tickets';
  static String supportTicketDetails(String ticketId) => '/driver/support/tickets/$ticketId';
  static String supportTicketReply(String ticketId) => '/driver/support/tickets/$ticketId/reply';

  // Emergency Contacts & SOS
  static const String emergencyContacts = '/driver/emergency-contacts';
  static String emergencyContactDetails(String id) => '/driver/emergency-contacts/$id';
  static String triggerRideSos(String rideId) => '/driver/rides/$rideId/sos';

  // Invoices & Receipts
  static String rideInvoice(String rideId) => '/driver/rides/$rideId/invoice';
  static String rideInvoiceHtml(String rideId) => '$baseUrl/driver/rides/$rideId/invoice.html';
  static String rideInvoiceLink(String rideId) => '/driver/rides/$rideId/invoice-link';

  // In-Ride Live Chat (Uber / Rapido Style)
  static String rideChat(String rideId) => '/rides/$rideId/chat';
  static String rideChatRead(String rideId) => '/rides/$rideId/chat/read';
  static const String driverChatQuickReplies = '/rides/chat/quick-replies?role=driver';

  // Lost & Found Items
  static const String driverLostItems = '/driver/lost-items';
  static String driverRespondLostItem(String id) => '/driver/lost-items/$id/respond';

  // Account Deletion
  static const String deletionReasons = '/driver/account/deletion-reasons';
  static const String deleteAccount = '/driver/account';
}
