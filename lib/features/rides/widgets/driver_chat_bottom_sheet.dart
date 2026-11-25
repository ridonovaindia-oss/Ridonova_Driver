import 'package:flutter/material.dart';
import '../presentation/screens/driver_chat_screen.dart';

export '../presentation/screens/driver_chat_screen.dart';

class DriverChatHelper {
  /// Opens the full-featured Driver Live Chat screen
  static Future<void> openChat(
    BuildContext context, {
    required String rideId,
    String riderName = 'Passenger',
    String? riderPhone,
    String? pickupAddress,
    String? destinationAddress,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DriverChatScreen(
          rideId: rideId,
          riderName: riderName,
          riderPhone: riderPhone,
          pickupAddress: pickupAddress,
          destinationAddress: destinationAddress,
        ),
      ),
    );
  }
}
