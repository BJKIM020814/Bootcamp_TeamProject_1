import 'package:flutter/material.dart';

import 'package:bootcamp_teamproject_1/common/review_image_view.dart';
import 'package:bootcamp_teamproject_1/services/api_client.dart';
import 'fitpick_mypage_ui.dart';

/// 로그인한 사용자가 MySQL에 작성한 리뷰를 조회한다.
class ReviewManagementPage extends StatefulWidget {
  const ReviewManagementPage({super.key});

  @override
  State<ReviewManagementPage> createState() => _ReviewManagementPageState();
}

class _ReviewManagementPageState extends State<ReviewManagementPage> {
  late Future<List<Map<String, dynamic>>> _reviews;

  @override
  void initState() {
    super.initState();
    _reviews = _loadReviews();
  }

  Future<List<Map<String, dynamic>>> _loadReviews() async {
    final response = await ApiClient.get(
      '/api/reviews',
      query: const {'limit': '100', 'offset': '0'},
    );
    if (response is! Map || response['items'] is! List) {
      throw ApiException('리뷰 서버 응답 형식이 올바르지 않습니다.');
    }
    return (response['items'] as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  void _retry() => setState(() => _reviews = _loadReviews());

  @override
  Widget build(BuildContext context) => FitpickMyPageScaffold(
    title: '리뷰 관리',
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _reviews,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ReviewMessage(
            icon: Icons.cloud_off_outlined,
            title: '리뷰를 불러오지 못했습니다.',
            description: '${snapshot.error}',
            action: OutlinedButton(
              onPressed: _retry,
              child: const Text('다시 시도'),
            ),
          );
        }
        final reviews = snapshot.data ?? const [];
        if (reviews.isEmpty) {
          return const FitpickEmptyState(
            icon: Icons.rate_review_outlined,
            title: '작성한 리뷰가 없습니다.',
            description: '구매한 상품의 리뷰가 등록되면 이곳에서 확인할 수 있습니다.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: reviews.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _ReviewCard(review: reviews[index]),
        );
      },
    ),
  );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final Map<String, dynamic> review;

  @override
  Widget build(BuildContext context) {
    final rating = num.tryParse('${review['rating']}') ?? 0;
    final date = '${review['createdAt'] ?? ''}'.split('T').first;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReviewImageView(
            imageUrl: review['imageUrl'] is String
                ? ApiClient.absoluteUrl(review['imageUrl'] as String)
                : null,
            height: 180,
          ),
          const SizedBox(height: 12),
          Text(
            '${review['productName'] ?? '상품'}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            '${review['brand'] ?? ''} · ${review['fit'] ?? '사이즈 정보 없음'} · $date',
            style: const TextStyle(fontSize: 12, color: Color(0xFF777777)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                color: Color(0xFFE1A63A),
                size: 19,
              ),
              const SizedBox(width: 4),
              Text(rating.toStringAsFixed(rating % 1 == 0 ? 0 : 1)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${review['content'] ?? ''}',
            style: const TextStyle(height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _ReviewMessage extends StatelessWidget {
  const _ReviewMessage({
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: const Color(0xFF999999)),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(description, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    ),
  );
}
