import 'package:flutter/material.dart';
import '../../features/auth/phone_login_screen.dart';
import '../utils/app_flushbar.dart';

class AppNavigator {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static BuildContext? get currentContext => navigatorKey.currentContext;

  /// Logs out driver session and redirects to PhoneLoginScreen with optional notice
  static void logoutAndRedirectToLogin({String message = 'Session expired. Please log in again.'}) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      AppFlushbar.warning(context, title: 'Session Expired', message: message);
    }
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
      (route) => false,
    );
  }
}

