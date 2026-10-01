import 'package:flutter/material.dart';
import 'dart:async';

import 'package:bootcamp_teamproject_1/discover/home_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1600), _moveToHome);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6C4EFF),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 서비스 로고를 대신하는 신발 아이콘 목업입니다.
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(
                  Icons.directions_walk_rounded,
                  size: 52,
                  color: Color(0xFF6C4EFF),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'FitPick',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '내 발에 꼭 맞는 한 켤레',
                style: TextStyle(color: Color(0xFFDCD4FF), fontSize: 15),
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
