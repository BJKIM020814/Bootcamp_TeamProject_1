import 'package:flutter/material.dart';
import '../../common/fitpick_snackbar.dart';
import '../../services/fitpick_api_service.dart';
import 'fitpick_mypage_ui.dart';

/// 로그인한 회원의 문의 등록·조회와 서버 FAQ를 제공한다.
class CustomerSupportPage extends StatefulWidget {
  const CustomerSupportPage({super.key});

  @override
  State<CustomerSupportPage> createState() => _CustomerSupportPageState();
}

class _CustomerSupportPageState extends State<CustomerSupportPage> {
  final FitpickApiService _api = FitpickApiService.instance;
  late Future<Map<String, dynamic>> _contacts = _api.contacts();
  late Future<Map<String, dynamic>> _faqs = _api.faqs();

  void _reloadContacts() {
    final contacts = _api.contacts();
    setState(() {
      _contacts = contacts;
    });
  }

  void _reloadFaqs() {
    final faqs = _api.faqs();
    setState(() {
      _faqs = faqs;
    });
  }

  Future<bool> _replyToInquiry(int id, String content) async {
    try {
      await _api.replyToContact(id, content);
      if (!mounted) return false;
      _reloadContacts();
      showFitpickSnackbar('문의에 메시지를 추가했습니다.', title: '완료');
      return true;
    } catch (error) {
      if (mounted) showFitpickSnackbar(_errorMessage(error), title: '오류');
      return false;
    }
  }

  Future<void> _writeInquiry() async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _InquiryComposer(),
    );
    if (!mounted || submitted != true) return;
    _reloadContacts();
    showFitpickSnackbar('문의가 접수되었습니다.', title: '완료');
  }

  @override
  Widget build(BuildContext context) => FitpickMyPageScaffold(
    title: '고객센터',
    body: RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _contacts = _api.contacts();
          _faqs = _api.faqs();
        });
        await Future.wait([_contacts, _faqs]);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          const Text(
            '무엇을 도와드릴까요?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _writeInquiry,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('1:1 문의 작성'),
            style: FilledButton.styleFrom(
              backgroundColor: fitpickBrandColor,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 26),
          const Text('내 문의', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _buildContacts(),
          const SizedBox(height: 26),
          const Text('자주 묻는 질문', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _buildFaqs(),
        ],
      ),
    ),
  );

  Widget _buildContacts() => FutureBuilder<Map<String, dynamic>>(
    future: _contacts,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError) {
        return _LoadError(
          message: _errorMessage(snapshot.error),
          onRetry: _reloadContacts,
        );
      }
      final rows = (snapshot.data!['items'] as List? ?? const [])
          .cast<Map<String, dynamic>>();
      if (rows.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Text('등록된 문의가 없습니다.', style: TextStyle(color: Colors.black54)),
        );
      }
      return Column(
        children: [
          for (final row in rows)
            _InquiryTile(row: row, onReply: _replyToInquiry),
        ],
      );
    },
  );

  Widget _buildFaqs() => FutureBuilder<Map<String, dynamic>>(
    future: _faqs,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError) {
        return _LoadError(
          message: _errorMessage(snapshot.error),
          onRetry: _reloadFaqs,
        );
      }
      final rows = (snapshot.data!['items'] as List? ?? const [])
          .cast<Map<String, dynamic>>();
      return Column(
        children: [
          for (final row in rows)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(row['question']?.toString() ?? ''),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(row['answer']?.toString() ?? ''),
                ),
              ],
            ),
        ],
      );
    },
  );

  String _errorMessage(Object? error) => error is FitpickApiException
      ? error.message
      : '데이터를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.';
}

class _InquiryTile extends StatefulWidget {
  const _InquiryTile({required this.row, required this.onReply});

  final Map<String, dynamic> row;
  final Future<bool> Function(int id, String content) onReply;

  @override
  State<_InquiryTile> createState() => _InquiryTileState();
}

class _InquiryTileState extends State<_InquiryTile> {
  final TextEditingController _reply = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final answered = (row['process'] as num?)?.toInt() == 1;
    final response = row['response']?.toString();
    final rawMessages = (row['messages'] as List? ?? const [])
        .whereType<Map>()
        .map((message) => Map<String, dynamic>.from(message))
        .toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(
          answered
              ? Icons.mark_email_read_outlined
              : Icons.mark_email_unread_outlined,
          color: answered ? Colors.green.shade700 : Colors.orange.shade800,
        ),
        title: Text(
          row['content']?.toString() ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(answered ? '답변 완료' : '답변 대기 중'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (rawMessages.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                response?.isNotEmpty == true
                    ? '답변: $response'
                    : '아직 등록된 답변이 없습니다.',
              ),
            ),
          for (final message in rawMessages)
            _InquiryMessageBubble(message: message),
          const SizedBox(height: 12),
          TextField(
            controller: _reply,
            minLines: 1,
            maxLines: 4,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: '추가 문의 메시지',
              border: OutlineInputBorder(),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: _sending ? null : _sendReply,
              child: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('메시지 보내기'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendReply() async {
    final content = _reply.text.trim();
    final id = (widget.row['id'] as num?)?.toInt();
    if (id == null || content.isEmpty || _sending) return;
    setState(() => _sending = true);
    final sent = await widget.onReply(id, content);
    if (mounted) {
      if (sent) _reply.clear();
      setState(() => _sending = false);
    }
  }
}

class _InquiryMessageBubble extends StatelessWidget {
  const _InquiryMessageBubble({required this.message});

  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context) {
    final isCustomer = message['authorRole'] == 'customer';
    return Align(
      alignment: isCustomer ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isCustomer ? const Color(0xFFEAF1FF) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCustomer ? '나' : '고객센터',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(message['content']?.toString() ?? ''),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(message, style: const TextStyle(color: Colors.red)),
      ),
      IconButton(onPressed: onRetry, icon: const Icon(Icons.refresh)),
    ],
  );
}

class _InquiryComposer extends StatefulWidget {
  const _InquiryComposer();

  @override
  State<_InquiryComposer> createState() => _InquiryComposerState();
}

class _InquiryComposerState extends State<_InquiryComposer> {
  final TextEditingController _content = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _content.text.trim();
    if (content.isEmpty) {
      setState(() => _error = '문의 내용을 입력해 주세요.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await FitpickApiService.instance.writeContact(content);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = error is FitpickApiException
              ? error.message
              : '문의 접수에 실패했습니다. 다시 시도해 주세요.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      12,
      20,
      20 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '1:1 문의 작성',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _content,
          autofocus: true,
          minLines: 5,
          maxLines: 9,
          maxLength: 2000,
          enabled: !_sending,
          decoration: const InputDecoration(
            hintText: '문의 내용을 자세히 입력해 주세요.',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 4),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _sending ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: fitpickBrandColor,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
          ),
          child: Text(_sending ? '접수 중…' : '문의 접수'),
        ),
      ],
    ),
  );
}
