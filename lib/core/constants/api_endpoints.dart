import '../network/api_constants.dart';

class ApiEndpoints {
  static const String driverCancelReasons = ApiConstants.driverCancelReasons;
  static String cancelDriverRide(String rideId) => ApiConstants.cancelDriverRide(rideId);

  // In-Ride Live Chat Endpoints (Uber / Rapido Style)
  static String rideChat(String rideId) => ApiConstants.rideChat(rideId);
  static String rideChatRead(String rideId) => ApiConstants.rideChatRead(rideId);
  static const String driverChatQuickReplies = ApiConstants.driverChatQuickReplies;
}
