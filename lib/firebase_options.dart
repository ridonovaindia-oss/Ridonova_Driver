import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Configured using parameters from android/app/google-services.json for Ridonova Driver App.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBaEDYPIy0zLwNniEbLwohjVBVff6uyhMQ',
    appId: '1:117890321123:web:742796220782b0803513d6',
    messagingSenderId: '117890321123',
    projectId: 'ridonova-bb2c7',
    authDomain: 'ridonova-bb2c7.firebaseapp.com',
    storageBucket: 'ridonova-bb2c7.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBaEDYPIy0zLwNniEbLwohjVBVff6uyhMQ',
    appId: '1:117890321123:android:742796220782b0803513d6',
    messagingSenderId: '117890321123',
    projectId: 'ridonova-bb2c7',
    storageBucket: 'ridonova-bb2c7.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBaEDYPIy0zLwNniEbLwohjVBVff6uyhMQ',
    appId: '1:117890321123:ios:742796220782b0803513d6',
    messagingSenderId: '117890321123',
    projectId: 'ridonova-bb2c7',
    storageBucket: 'ridonova-bb2c7.firebasestorage.app',
    iosBundleId: 'com.app.ridonova_driver',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBaEDYPIy0zLwNniEbLwohjVBVff6uyhMQ',
    appId: '1:117890321123:ios:742796220782b0803513d6',
    messagingSenderId: '117890321123',
    projectId: 'ridonova-bb2c7',
    storageBucket: 'ridonova-bb2c7.firebasestorage.app',
    iosBundleId: 'com.app.ridonova_driver',
  );
}
