import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    if (defaultTargetPlatform == TargetPlatform.iOS) return ios;
    if (defaultTargetPlatform == TargetPlatform.android) return android;
    throw UnsupportedError(
      'Firebase is configured for iOS, Android, and web only.',
    );
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCkjzrLuFc3j5RlOybqNFhi9fdgY_8o6YU',
    appId: '1:864946455276:ios:043a137bf59fa64faa1bc9',
    messagingSenderId: '864946455276',
    projectId: 'shoe-20260930',
    storageBucket: 'shoe-20260930.firebasestorage.app',
    iosBundleId: 'com.example.bootcampTeamproject1',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDYv4HzxB2jhwgH7Mo9a3To8mEMHbg_19Y',
    appId: '1:864946455276:android:48c5863e7b2b6ea5aa1bc9',
    messagingSenderId: '864946455276',
    projectId: 'shoe-20260930',
    storageBucket: 'shoe-20260930.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDCJ4em460oVz5mOrJ5Rj-V_XJZm8llIjM',
    appId: '1:864946455276:web:6a5c6930622a04d7aa1bc9',
    messagingSenderId: '864946455276',
    projectId: 'shoe-20260930',
    authDomain: 'shoe-20260930.firebaseapp.com',
    storageBucket: 'shoe-20260930.firebasestorage.app',
  );
}
