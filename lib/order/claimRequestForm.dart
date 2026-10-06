import 'dart:typed_data';

import 'package:bootcamp_teamproject_1/order/cartPage.dart';
import 'package:bootcamp_teamproject_1/order/exchangeHistoryPage.dart';
import 'package:bootcamp_teamproject_1/order/orderApi.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

/// 교환·반품 신청 공통 화면. 선택 값(사유·사이즈·매장·환불액)은
/// 서버(/claim-options)에서 받고, 신청은 /claims 로 보낸다. 사진은 base64 로 함께 업로드된다.
class ClaimRequestForm extends StatefulWidget {
  const ClaimRequestForm({
    super.key,
    required this.orderNumber,
    required this.orderItemId,
    required this.isExchange,
  });

  final String orderNumber;
  final int orderItemId;
  final bool isExchange;

  @override
  State<ClaimRequestForm> createState() => _ClaimRequestFormState();
}

class _ClaimRequestFormState extends State<ClaimRequestForm> {
  static const _maxPhotoBytes = 5 * 1024 * 1024;

  final _detailController = TextEditingController();

  ClaimOptions? _options;
  String? _loadError;
  bool _submitting = false;

  String _reason = '';
  int? _newSize;
  int? _storeSeq;
  final List<Uint8List> _photos = [];

  String get _typeLabel => widget.isExchange ? '교환' : '반품';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final options = await OrderApi.claimOptions(
        widget.orderNumber,
        widget.orderItemId,
      );
      if (!mounted) return;
      final sizes = _exchangeSizes(options);
      setState(() {
        _options = options;
        _storeSeq = options.stores.any((s) => s.seq == options.defaultDealerSeq)
            ? options.defaultDealerSeq
            : (options.stores.isEmpty ? null : options.stores.first.seq);
        _newSize = sizes.isEmpty ? null : sizes.first;
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = error.toString());
    }
  }

  /// 교환 가능한 사이즈: 같은 SKU 로 등록된 사이즈 중 현재 사이즈를 뺀 값.
  /// 등록된 옵션이 없으면 220~310mm(5mm 단위)에서 고른다.
  List<int> _exchangeSizes(ClaimOptions options) {
    final registered = options.availableSizes;
    final all = registered.isNotEmpty
        ? registered
        : [for (var s = 220; s <= 310; s += 5) s];
    return all.where((size) => size != options.item.size).toList();
  }

  Future<void> _pickPhoto() async {
    final max = _options?.maxPhotos ?? 3;
    if (_photos.length >= max) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.length > _maxPhotoBytes) {
      _showError('사진은 5MB 이하만 첨부할 수 있습니다.');
      return;
    }
    setState(() => _photos.add(bytes));
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_reason.isEmpty) {
      _showError('$_typeLabel 사유를 선택해 주세요.');
      return;
    }
    if (_detailController.text.trim().length < 5) {
      _showError('상세 사유를 5자 이상 입력해 주세요.');
      return;
    }
    if (widget.isExchange && _newSize == null) {
      _showError('교환할 사이즈를 선택해 주세요.');
      return;
    }
    if (_storeSeq == null) {
      _showError('방문할 매장을 선택해 주세요.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await OrderApi.createClaim(
        orderNumber: widget.orderNumber,
        orderItemId: widget.orderItemId,
        claimType: widget.isExchange ? 'EXCHANGE' : 'RETURN',
        reason: _reason,
        detail: _detailController.text.trim(),
        dealerSeq: _storeSeq!,
        requestedSize: widget.isExchange ? _newSize : null,
        photos: _photos,
      );
      if (!mounted) return;
      Get.off(() => const Exchangehistorypage());
    } catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;
    return Scaffold(
      appBar: AppBar(
        title: Text('$_typeLabel 신청'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => Get.to(() => const Cartpage()),
            icon: Icon(Icons.shopping_bag_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: _loadError != null
            ? _buildErrorState(_loadError!)
            : options == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      children: [
                        _buildInfoNotice(options),
                        const SizedBox(height: 16),
                        _buildProductCard(options.item),
                        const SizedBox(height: 24),
                        _sectionTitle('신청 사유'),
                        const SizedBox(height: 8),
                        _buildReasonDropdown(options),
                        const SizedBox(height: 20),
                        _sectionTitle('상세 사유'),
                        const SizedBox(height: 8),
                        _buildDetailField(),
                        if (widget.isExchange) ...[
                          const SizedBox(height: 24),
                          _sectionTitle('교환할 사이즈'),
                          const SizedBox(height: 10),
                          _buildSizePreview(options),
                          const SizedBox(height: 10),
                          _buildSizeDropdown(options),
                          const SizedBox(height: 8),
                          Text(
                            '본사에서 교환 상품을 준비한 뒤 수령 매장으로 발송합니다.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                        const SizedBox(height: 24),
                        _buildPhotoSectionTitle(options),
                        const SizedBox(height: 10),
                        _buildPhotoPicker(options),
                        const SizedBox(height: 8),
                        Text(
                          'JPG, PNG, WEBP · 최대 ${options.maxPhotos}장 · 각 5MB 이하',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 24),
                        _sectionTitle('방문 매장'),
                        const SizedBox(height: 8),
                        _buildStoreDropdown(options),
                        const SizedBox(height: 20),
                        if (!widget.isExchange) ...[
                          _buildRefundRow(options.refundAmount),
                          const SizedBox(height: 10),
                        ],
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '신청 접수 → 본사 확인 → 매장 방문·상품 확인 → ${widget.isExchange ? '교환' : '환불'} 완료 순서로 진행됩니다.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildBottomAction(options),
                ],
              ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildInfoNotice(ClaimOptions options) {
    final blocked = !options.eligible;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: blocked ? const Color(0xFFFFF4E0) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        blocked
            ? options.notice ?? '$_typeLabel 신청을 할 수 없는 상품입니다.'
            : '주문번호 ${widget.orderNumber}의 상품 1개를 $_typeLabel 신청합니다.',
        style: TextStyle(
          fontSize: 12,
          color: blocked ? Colors.brown.shade700 : Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildProductCard(OrderLine item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: item.imageUrl == null
                ? const Icon(Icons.image_outlined, color: Colors.grey)
                : Image.network(
                    item.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.image_outlined, color: Colors.grey),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.brand,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  item.name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  item.optionLabel,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      formatWon(item.price),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '수량 ${item.quantity}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }

  Widget _buildReasonDropdown(ClaimOptions options) {
    return DropdownButtonFormField<String>(
      initialValue: _reason,
      decoration: _dropdownDecoration(),
      items: [
        for (final reason in ['', ...options.reasons])
          DropdownMenuItem(
            value: reason,
            child: Text(
              reason.isEmpty ? '사유를 선택해 주세요' : reason,
              style: TextStyle(
                color: reason.isEmpty ? Colors.grey.shade600 : Colors.black,
              ),
            ),
          ),
      ],
      onChanged: (value) => setState(() => _reason = value ?? ''),
    );
  }

  Widget _buildDetailField() {
    return TextField(
      controller: _detailController,
      maxLines: 4,
      maxLength: 500,
      decoration: InputDecoration(
        hintText: '어떤 점이 불편했는지 5자 이상 알려주세요.',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildSizePreview(ClaimOptions options) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            options.item.sizeLabel,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 16),
          Icon(Icons.arrow_forward, color: Colors.grey.shade400),
          const SizedBox(width: 16),
          Text(
            _newSize == null ? '-' : '${_newSize}mm',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSizeDropdown(ClaimOptions options) {
    final sizes = _exchangeSizes(options);
    return DropdownButtonFormField<int>(
      initialValue: _newSize,
      decoration: _dropdownDecoration(),
      items: [
        for (final size in sizes)
          DropdownMenuItem(value: size, child: Text('${size}mm')),
      ],
      onChanged: (value) => setState(() => _newSize = value ?? _newSize),
    );
  }

  Widget _buildPhotoSectionTitle(ClaimOptions options) {
    return Row(
      children: [
        _sectionTitle('사진 첨부 (선택)'),
        const Spacer(),
        Text(
          '${_photos.length}/${options.maxPhotos}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildPhotoPicker(ClaimOptions options) {
    return Row(
      children: [
        for (var i = 0; i < _photos.length; i++) ...[
          _buildPhotoThumbnail(i),
          const SizedBox(width: 10),
        ],
        if (_photos.length < options.maxPhotos) _buildAddPhotoTile(),
      ],
    );
  }

  Widget _buildPhotoThumbnail(int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            _photos[index],
            width: 84,
            height: 84,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: () => _removePhoto(index),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddPhotoTile() {
    return GestureDetector(
      onTap: _pickPhoto,
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_outlined, color: Colors.grey.shade500),
            const SizedBox(height: 4),
            Text(
              '사진 선택',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreDropdown(ClaimOptions options) {
    return DropdownButtonFormField<int>(
      initialValue: _storeSeq,
      isExpanded: true,
      decoration: _dropdownDecoration(),
      items: [
        for (final store in options.stores)
          DropdownMenuItem(
            value: store.seq,
            child: Text(store.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) => setState(() => _storeSeq = value ?? _storeSeq),
    );
  }

  Widget _buildRefundRow(int refund) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '예상 환불금액',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
        ),
        Text(
          formatWon(refund),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildBottomAction(ClaimOptions options) {
    final enabled = options.eligible && !_submitting;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: enabled ? _submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            _submitting ? '신청 중…' : '$_typeLabel 신청하기',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
