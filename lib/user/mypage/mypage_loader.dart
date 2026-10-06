import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:bootcamp_teamproject_1/user/authController.dart';

import 'mypage_common.dart';

/// 로그인한 계정의 데이터를 서버에서 불러와 보여주는 공통 틀.
/// 로딩 중 / 실패(다시 시도) / 로그인 필요 상태를 대신 처리한다.
class MpLoader<T> extends StatefulWidget {
  const MpLoader({super.key, required this.load, required this.builder});

  /// customerId(email)를 받아 데이터를 불러온다.
  final Future<T> Function(String customerId) load;
  final Widget Function(BuildContext context, T data) builder;

  @override
  State<MpLoader<T>> createState() => _MpLoaderState<T>();
}

class _MpLoaderState<T> extends State<MpLoader<T>> {
  Future<T>? _future;
  late final Worker _accountWorker;

  @override
  void initState() {
    super.initState();
    _reload();
    // 로그인 계정이 바뀌면 이전 계정의 화면 데이터를 폐기하고 다시 조회한다.
    _accountWorker = ever(AuthController.to.customerId, (_) {
      if (mounted) setState(_reload);
    });
  }

  @override
  void dispose() {
    _accountWorker.dispose();
    super.dispose();
  }

  void _reload() {
    final id = AuthController.to.customerId.value;
    _future = id == null ? null : widget.load(id);
  }

  Widget _message(String text, {VoidCallback? onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: MpColors.sub),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final future = _future;
    if (future == null) return _message('로그인이 필요합니다.');
    return FutureBuilder<T>(
      key: ValueKey(AuthController.to.customerId.value),
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _message(
            '${snapshot.error}',
            onRetry: () => setState(_reload),
          );
        }
        return widget.builder(context, snapshot.data as T);
      },
    );
  }
}
