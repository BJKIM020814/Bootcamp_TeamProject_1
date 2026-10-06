import 'package:flutter/material.dart';
import 'dart:async';

import 'package:bootcamp_teamproject_1/discover/home_page.dart';

/// 브랜드 시작 화면을 잠시 노출한 다음 Discover 홈으로 교체한다.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    // 네트워크 요청을 기다리지 않고 고정 시간 뒤 화면을 넘긴다.
    Timer(const Duration(milliseconds: 1100), _moveToHome);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF9),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 홈 화면과 동일한 중립 색상과 로고로 시작 상태를 표시한다.
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: const Color(0xFF272A2D),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Icon(
                  Icons.directions_walk_rounded,
                  size: 52,
                  color: Color(0xFFFFFDF9),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'FitPick',
                style: TextStyle(
                  color: Color(0xFF272A2D),
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '내 발에 꼭 맞는 한 켤레',
                style: TextStyle(color: Color(0xFF827A71), fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 스플래시 노출 후 홈 화면으로 교체 이동합니다.
  void _moveToHome() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
  }
}
