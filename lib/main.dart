import 'package:bootcamp_teamproject_1/discover/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import 'firebase_options.dart';
import 'services/erd_seed_service.dart';

/// 플랫폼별 Firebase 초기화 후 Discover 시작 화면을 실행한다.
/// `SEED_ERD=true`는 개발용 Firestore 시드를 별도로 요청한 경우에만 동작한다.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const naverMapClientId = String.fromEnvironment('NAVER_MAP_CLIENT_ID');
  if (naverMapClientId.isNotEmpty && !kIsWeb) {
    await FlutterNaverMap().init(
      clientId: naverMapClientId,
      onAuthFailed: (error) => debugPrint(
        'Naver Map authentication failed: code=${error.code}, '
        'message=${error.message ?? "(no message)"}',
      ),
    );
  }
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
    // GetX 라우팅/상태관리와 전 화면 공통 테마를 한 앱 범위에 적용한다.
    return GetMaterialApp(
      title: 'FitPick',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C4EFF)),
        scaffoldBackgroundColor: const Color(0xFFFFFDF9),
        useMaterial3: true,
        textTheme: GoogleFonts.notoSansKrTextTheme(),
      ),
      home: const SplashPage(),
    );
  }
}
