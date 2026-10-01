import 'package:bootcamp_teamproject_1/user/mypage/customersupportpage.dart';
import 'package:bootcamp_teamproject_1/user/mypage/fitpick_mypage_ui.dart';
import 'package:bootcamp_teamproject_1/user/mypage/notificationpage.dart';
import 'package:bootcamp_teamproject_1/user/mypage/recentlyviewedpage.dart';
import 'package:bootcamp_teamproject_1/user/mypage/reviewmanagementpage.dart';
import 'package:bootcamp_teamproject_1/user/mypage/reviewwritepage.dart';
import 'package:bootcamp_teamproject_1/user/mypage/settingspage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'services/erd_seed_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (const bool.fromEnvironment('SEED_ERD')) {
    await ErdSeedService().seedTestData();
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase ERD',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const SettingsPage(),
    );
  }
}
