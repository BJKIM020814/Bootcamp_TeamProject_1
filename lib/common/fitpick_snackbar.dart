import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 앱 전역 알림을 GetX snackbar로 동일한 위치와 스타일로 표시한다.
void showFitpickSnackbar(String message, {String title = '안내'}) {
  Get.snackbar(
    title,
    message,
    snackPosition: SnackPosition.BOTTOM,
    duration: const Duration(seconds: 3),
    margin: const EdgeInsets.all(12),
    borderRadius: 12,
    backgroundColor: const Color(0xEE222222),
    colorText: Colors.white,
    animationDuration: const Duration(milliseconds: 250),
  );
}
