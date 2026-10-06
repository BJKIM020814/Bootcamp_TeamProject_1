import 'package:flutter/material.dart';

import 'fitpick_mypage_ui.dart';

/// 09. 리뷰 작성
///
/// MySQL 리뷰/작성 API는 있으나 이 화면은 아직 API를 연결하지 않아 실제 등록되지 않는다.
class ReviewWritePage extends StatefulWidget {
  const ReviewWritePage({super.key});

  @override
  State<ReviewWritePage> createState() => _ReviewWritePageState();
}

class _ReviewWritePageState extends State<ReviewWritePage> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  int _rating = 5;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    // 입력값 검증까지만 수행한다. API 호출이나 리뷰 저장은 연결되어 있지 않다.
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('리뷰 데이터 모델 연결 후 등록할 수 있습니다.')));
  }

  @override
  Widget build(BuildContext context) => FitpickMyPageScaffold(
    title: '리뷰 작성',
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          const Text(
            '상품은 어떠셨나요?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (index) => IconButton(
                onPressed: () => setState(() => _rating = index + 1),
                icon: Icon(
                  index < _rating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: const Color(0xFFFFB800),
                  size: 34,
                ),
              ),
            ),
          ),
          Center(
            child: Text(
              '$_rating점',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _contentController,
            minLines: 6,
            maxLines: 8,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              labelText: '리뷰 내용',
              hintText: '상품에 대한 솔직한 후기를 남겨 주세요.',
              border: OutlineInputBorder(),
            ),
            validator: (value) => (value?.trim().length ?? 0) >= 10
                ? null
                : '리뷰는 10자 이상 입력해 주세요.',
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(backgroundColor: fitpickBrandColor),
              child: const Text('리뷰 등록'),
            ),
          ),
        ],
      ),
    ),
  );
}
