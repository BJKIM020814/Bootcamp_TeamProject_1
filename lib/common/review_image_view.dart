import 'package:flutter/material.dart';

/// 리뷰 사진을 정해진 높이에 표시하고, 사진 없음/로드 실패를 명확하게 구분합니다.
class ReviewImageView extends StatelessWidget {
  const ReviewImageView({
    super.key,
    required this.imageUrl,
    this.height = 180,
    this.borderRadius = 12,
  });

  final String? imageUrl;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: url == null || url.isEmpty
            ? const _ReviewImagePlaceholder(
                icon: Icons.image_not_supported_outlined,
                message: '등록된 이미지가 없습니다',
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _ReviewImagePlaceholder(
                  icon: Icons.broken_image_outlined,
                  message: '이미지를 불러오지 못했습니다',
                ),
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const _ReviewImagePlaceholder(
                        icon: Icons.image_outlined,
                        message: '이미지를 불러오는 중입니다',
                      ),
              ),
      ),
    );
  }
}

class _ReviewImagePlaceholder extends StatelessWidget {
  const _ReviewImagePlaceholder({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFF1F2F3),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 38, color: const Color(0xFF9AA1A6)),
        const SizedBox(height: 8),
        Text(
          message,
          style: const TextStyle(fontSize: 12, color: Color(0xFF777F84)),
        ),
      ],
    ),
  );
}
