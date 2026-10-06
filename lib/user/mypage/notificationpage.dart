import 'package:bootcamp_teamproject_1/common/fitpick_snackbar.dart';
import 'package:bootcamp_teamproject_1/services/fitpick_api_service.dart';
import 'package:flutter/material.dart';

/// 서버에 저장된 주문·문의 알림을 조회하고 읽음 처리한다.
class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final _api = FitpickApiService.instance;
  List<Map<String, dynamic>> _items = const [];
  int _unreadCount = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.notifications(limit: 100);
      if (!mounted) return;
      setState(() {
        _items = (result['items'] as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _unreadCount = result['unreadCount'] as int? ?? 0;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _read(int id) async {
    try {
      await _api.readNotification(id);
      await _load();
    } catch (error) {
      if (mounted) showFitpickSnackbar('$error', title: '알림');
    }
  }

  Future<void> _readAll() async {
    try {
      await _api.readAllNotifications();
      await _load();
    } catch (error) {
      if (mounted) showFitpickSnackbar('$error', title: '알림');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      centerTitle: true,
      title: const Text('알림', style: TextStyle(fontWeight: FontWeight.w800)),
      actions: [
        if (_unreadCount > 0)
          TextButton(onPressed: _readAll, child: const Text('모두 읽음')),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ListView(
              children: [
                const SizedBox(height: 160),
                Center(child: Text(_error!, textAlign: TextAlign.center)),
                Center(
                  child: TextButton(
                    onPressed: _load,
                    child: const Text('다시 시도'),
                  ),
                ),
              ],
            )
          : _items.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 180),
                Icon(
                  Icons.notifications_none_rounded,
                  size: 48,
                  color: Colors.grey,
                ),
                SizedBox(height: 12),
                Center(child: Text('새로운 알림이 없습니다.')),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _items[index];
                final id = item['id'] as int;
                final unread = item['readAt'] == null;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: unread
                        ? const Color(0xFFEAF1EE)
                        : const Color(0xFFF3F1EE),
                    child: Icon(
                      item['category'] == 'order'
                          ? Icons.local_shipping_outlined
                          : Icons.notifications_none_rounded,
                      color: const Color(0xFF315A48),
                    ),
                  ),
                  title: Text(
                    '${item['title'] ?? '알림'}',
                    style: TextStyle(
                      fontWeight: unread ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    '${item['body'] ?? ''}\n${item['createdAt'] ?? ''}',
                  ),
                  isThreeLine: true,
                  trailing: unread
                      ? const Icon(
                          Icons.circle,
                          size: 9,
                          color: Color(0xFF315A48),
                        )
                      : null,
                  onTap: unread ? () => _read(id) : null,
                );
              },
            ),
    ),
  );
}
