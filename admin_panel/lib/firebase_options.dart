// Same Firebase project as the FaceBaby mobile app (facebaby-afc41).
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
        return windows;
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
    apiKey: 'AIzaSyCAH2I67pZXfJGPI2BMObe3GWg0IA_FR9o',
    appId: '1:91181989163:web:c0635f7dc0047ac17c596e',
    messagingSenderId: '91181989163',
    projectId: 'facebaby-afc41',
    authDomain: 'facebaby-afc41.firebaseapp.com',
    storageBucket: 'facebaby-afc41.firebasestorage.app',
    measurementId: 'G-2FW8R27WZ6',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBpkPL8Sa5DWQUCwccwgJm9Gdz_oRC-z8w',
    appId: '1:91181989163:android:5f4ca3cf26c344677c596e',
    messagingSenderId: '91181989163',
    projectId: 'facebaby-afc41',
    storageBucket: 'facebaby-afc41.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDsnuG6BTKXf0ZKss5q-cOsfUS2Z_C-mh0',
    appId: '1:91181989163:ios:fca6ab95507293657c596e',
    messagingSenderId: '91181989163',
    projectId: 'facebaby-afc41',
    storageBucket: 'facebaby-afc41.firebasestorage.app',
    iosBundleId: 'com.example.facebabyFlutter',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDsnuG6BTKXf0ZKss5q-cOsfUS2Z_C-mh0',
    appId: '1:91181989163:ios:fca6ab95507293657c596e',
    messagingSenderId: '91181989163',
    projectId: 'facebaby-afc41',
    storageBucket: 'facebaby-afc41.firebasestorage.app',
    iosBundleId: 'com.example.facebabyFlutter',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCAH2I67pZXfJGPI2BMObe3GWg0IA_FR9o',
    appId: '1:91181989163:web:1f68fde55ae0888a7c596e',
    messagingSenderId: '91181989163',
    projectId: 'facebaby-afc41',
    authDomain: 'facebaby-afc41.firebaseapp.com',
    storageBucket: 'facebaby-afc41.firebasestorage.app',
    measurementId: 'G-P5V0R76KDJ',
  );
}
