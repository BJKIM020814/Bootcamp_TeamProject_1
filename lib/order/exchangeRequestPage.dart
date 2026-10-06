import 'dart:io';

import 'package:bootcamp_teamproject_1/order/cartPage.dart';
import 'package:bootcamp_teamproject_1/order/exchangeHistoryPage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

/// 교환 신청 입력 UI. 제출 데이터는 현재 서버/DB에 저장되지 않는다.
class Exchangerequestpage extends StatefulWidget {
  const Exchangerequestpage({
    super.key,
    this.brand = 'NIKE',
    this.productName = "에어 포스 1 '07",
    this.colorLabel = '화이트 / 화이트 · 265mm',
    this.price = 119000,
    this.quantity = 1,
    this.currentSize = '265mm',
  });

  final String brand;
  final String productName;
  final String colorLabel;
  final int price;
  final int quantity;
  final String currentSize;

  @override
  State<Exchangerequestpage> createState() => _ExchangerequestpageState();
}

class _ExchangerequestpageState extends State<Exchangerequestpage> {
  static const _reasons = [
    '',
    '사이즈가 작아요',
    '사이즈가 커요',
    '상품이 설명과 달라요',
    '상품에 문제가 있어요',
    '기타',
  ];

  static final _sizes = [for (var s = 220; s <= 310; s += 5) '${s}mm'];

  static const _stores = ['강남 스토어', '신사 스토어', '성수 스토어', '홍대 스토어'];

  static const _maxPhotos = 3;

  final _detailController = TextEditingController();

  String _reason = '';
  late String _newSize = _sizes.contains('230mm') ? '230mm' : widget.currentSize;
  String _store = '성수 스토어';
  final List<XFile> _photos = [];

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  String _formatWon(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      if (i > 0 && remaining % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return '₩$buffer';
  }

  Future<void> _pickPhoto() async {
    if (_photos.length >= _maxPhotos) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _photos.add(picked));
    }
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _submit() {
    if (_reason.isEmpty) {
      _showError('교환 사유를 선택해 주세요.');
      return;
    }
    if (_detailController.text.trim().length < 5) {
      _showError('상세 사유를 5자 이상 입력해 주세요.');
      return;
    }
    Get.to(() => const Exchangehistorypage());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('교환 신청'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => Get.to(Cartpage()),
            icon: Icon(Icons.shopping_bag_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                children: [
                  _buildInfoNotice(),
                  const SizedBox(height: 16),
                  _buildProductCard(),
                  const SizedBox(height: 24),
                  _sectionTitle('신청 사유'),
                  const SizedBox(height: 8),
                  _buildReasonDropdown(),
                  const SizedBox(height: 20),
                  _sectionTitle('상세 사유'),
                  const SizedBox(height: 8),
                  _buildDetailField(),
                  const SizedBox(height: 24),
                  _sectionTitle('교환할 사이즈'),
                  const SizedBox(height: 10),
                  _buildSizePreview(),
                  const SizedBox(height: 10),
                  _buildSizeDropdown(),
                  const SizedBox(height: 8),
                  Text(
                    '본사에서 교환 상품을 준비한 뒤 수령 매장으로 발송합니다. (시연)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  _buildPhotoSectionTitle(),
                  const SizedBox(height: 10),
                  _buildPhotoPicker(),
                  const SizedBox(height: 8),
                  Text(
                    'JPG, PNG, WEBP · 최대 3장 · 각 10MB 이하',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                  Text(
                    '사진은 이 브라우저에서만 표시되며 서버에 업로드되지 않습니다.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle('방문 매장'),
                  const SizedBox(height: 8),
                  _buildStoreDropdown(),
                  const SizedBox(height: 8),
                  Text(
                    '신청 → 매장 확인 → 방문·상품 확인 → 교환 완료 순서로 진행됩니다.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            _buildBottomAction(),
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

  Widget _buildInfoNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '현재 주문의 1개 품목을 함께 신청합니다. 실제 접수·환불 기능은 연결되지 않았습니다.',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
      ),
    );
  }

  Widget _buildProductCard() {
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
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.image_outlined, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.brand,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  widget.productName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.colorLabel,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      _formatWon(widget.price),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '수량 ${widget.quantity}',
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

  Widget _buildReasonDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _reason,
      decoration: _dropdownDecoration(),
      items: [
        for (final reason in _reasons)
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

  Widget _buildSizePreview() {
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
            widget.currentSize,
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
            _newSize,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSizeDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _newSize,
      decoration: _dropdownDecoration(),
      items: [
        for (final size in _sizes) DropdownMenuItem(value: size, child: Text(size)),
      ],
      onChanged: (value) => setState(() => _newSize = value ?? _newSize),
    );
  }

  Widget _buildPhotoSectionTitle() {
    return Row(
      children: [
        _sectionTitle('사진 첨부 (선택)'),
        const Spacer(),
        Text(
          '${_photos.length}/$_maxPhotos',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildPhotoPicker() {
    return Row(
      children: [
        for (var i = 0; i < _photos.length; i++) ...[
          _buildPhotoThumbnail(i),
          const SizedBox(width: 10),
        ],
        if (_photos.length < _maxPhotos) _buildAddPhotoTile(),
      ],
    );
  }

  Widget _buildPhotoThumbnail(int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            File(_photos[index].path),
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

  Widget _buildStoreDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _store,
      decoration: _dropdownDecoration(),
      items: [
        for (final store in _stores) DropdownMenuItem(value: store, child: Text(store)),
      ],
      onChanged: (value) => setState(() => _store = value ?? _store),
    );
  }

  Widget _buildBottomAction() {
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
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            '교환 신청하기 · 시연',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
