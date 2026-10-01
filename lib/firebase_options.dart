import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    if (defaultTargetPlatform == TargetPlatform.iOS) return ios;
    throw UnsupportedError('Firebase is configured for iOS and web only.');
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCkjzrLuFc3j5RlOybqNFhi9fdgY_8o6YU',
    appId: '1:864946455276:ios:043a137bf59fa64faa1bc9',
    messagingSenderId: '864946455276',
    projectId: 'shoe-20260930',
    storageBucket: 'shoe-20260930.firebasestorage.app',
    iosBundleId: 'com.example.bootcampTeamproject1',
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
