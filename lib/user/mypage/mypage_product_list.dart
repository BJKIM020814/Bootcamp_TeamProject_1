import 'package:flutter/material.dart';
import 'package:bootcamp_teamproject_1/common/fitpick_snackbar.dart';
import 'package:bootcamp_teamproject_1/services/api_client.dart';

import 'mypage_common.dart';

/// 찜한 상품 / 최근 본 상품 공용 상품 모델
class MpProduct {
  final String pCode; // product.p_code
  final String brand; // 나이키, 아디다스 ...
  final String brandEn; // NIKE ...
  final String name;
  final int price;
  final String target; // 남성·공용 / 여성용 / 아동용
  final String targetLabel; // 공용 / 여성 / 아동
  final String purpose; // 러닝화 / 데일리 / 클래식 / 아웃도어
  final String? imageUrl;
  bool liked;

  MpProduct({
    this.pCode = '',
    required this.brand,
    required this.brandEn,
    required this.name,
    required this.price,
    required this.target,
    required this.targetLabel,
    this.purpose = '', // DB 에 용도 컬럼이 없어 비어 있을 수 있다
    this.imageUrl,
    this.liked = false,
  });

  static const _brandEn = {
    '나이키': 'NIKE',
    '아디다스': 'ADIDAS',
    '뉴발란스': 'NEW BALANCE',
    '아식스': 'ASICS',
    '푸마': 'PUMA',
  };

  /// 서버(/wishlist, /recently-viewed) 응답으로 만든다.
  factory MpProduct.fromJson(Map<String, dynamic> json) {
    final brand = json['brand'] as String;
    final gender = json['gender'] as String;
    return MpProduct(
      pCode: json['p_code'] as String,
      brand: brand,
      brandEn: _brandEn[brand] ?? brand,
      name: json['name'] as String,
      price: json['price'] as int,
      target: gender.contains('여')
          ? '여성용'
          : (gender.contains('아동') ? '아동용' : '남성·공용'),
      targetLabel: gender,
      imageUrl: ApiClient.absoluteUrl(json['image_url'] as String),
      liked: json['liked'] as bool,
    );
  }
}

String _won(int v) {
  final s = v.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
  return '₩$s';
}

/// 검색 + 필터 칩 + 정렬 + 2열 그리드 화면 본문
class MpProductListView extends StatefulWidget {
  final List<MpProduct> products;

  /// true면 하트를 해제했을 때 목록에서 제거 (찜한 상품)
  final bool removeOnUnlike;

  /// 하트를 눌렀을 때 서버에 반영하는 콜백. p.liked 는 이미 바뀐 값이며, 던지면 되돌린다.
  final Future<void> Function(MpProduct product)? onToggleLike;

  const MpProductListView({
    super.key,
    required this.products,
    this.removeOnUnlike = false,
    this.onToggleLike,
  });

  @override
  State<MpProductListView> createState() => _MpProductListViewState();
}

class _MpProductListViewState extends State<MpProductListView> {
  static const _targets = ['전체', '남성·공용', '여성용', '아동용'];
  static const _brands = ['전체', '나이키', '아디다스', '뉴발란스', '아식스'];
  static const _purposes = ['전체', '러닝화', '데일리', '클래식', '아웃도어'];
  static const _sorts = ['추천순', '낮은 가격순', '높은 가격순'];

  late final List<MpProduct> _items = List.of(widget.products);
  String _query = '';
  String _target = '전체';
  String _brand = '전체';
  String _purpose = '전체';
  String _sort = '추천순';

  List<MpProduct> get _filtered {
    final list = _items.where((p) {
      final q = _query.trim().toLowerCase();
      final matchQuery =
          q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.brand.toLowerCase().contains(q) ||
          p.brandEn.toLowerCase().contains(q);
      return matchQuery &&
          (_target == '전체' || p.target == _target) &&
          (_brand == '전체' || p.brand == _brand) &&
          (_purpose == '전체' || p.purpose == _purpose);
    }).toList();
    if (_sort == '낮은 가격순') {
      list.sort((a, b) => a.price.compareTo(b.price));
    } else if (_sort == '높은 가격순') {
      list.sort((a, b) => b.price.compareTo(a.price));
    }
    return list;
  }

  Future<void> _toggleLike(MpProduct p) async {
    final index = _items.indexOf(p);
    setState(() {
      p.liked = !p.liked;
      if (widget.removeOnUnlike && !p.liked) _items.remove(p);
    });
    try {
      await widget.onToggleLike?.call(p);
    } catch (e) {
      // 서버 반영에 실패하면 화면도 원래대로 되돌린다.
      if (!mounted) return;
      setState(() {
        p.liked = !p.liked;
        if (!_items.contains(p)) _items.insert(index < 0 ? 0 : index, p);
      });
      showFitpickSnackbar('$e', title: '오류');
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        _buildSearch(),
        const SizedBox(height: 16),
        _chipSection(
          '대상',
          _targets,
          _target,
          (v) => setState(() => _target = v),
        ),
        _chipSection('브랜드', _brands, _brand, (v) => setState(() => _brand = v)),
        if (_items.any((p) => p.purpose.isNotEmpty))
          _chipSection(
            '용도',
            _purposes,
            _purpose,
            (v) => setState(() => _purpose = v),
          ),
        const SizedBox(height: 4),
        _buildCountSort(items.length),
        const SizedBox(height: 16),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: Text(
                '조건에 맞는 상품이 없어요.',
                style: TextStyle(color: MpColors.sub),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 24,
              mainAxisExtent: 330,
            ),
            itemBuilder: (_, i) => _buildCard(items[i]),
          ),
      ],
    );
  }

  Widget _buildSearch() {
    return TextField(
      onChanged: (v) => setState(() => _query = v),
      style: const TextStyle(fontSize: 15, color: MpColors.ink),
      decoration: InputDecoration(
        hintText: '상품명, 브랜드 검색',
        hintStyle: const TextStyle(color: Color(0xFFB5BDC4), fontSize: 15),
        prefixIcon: const Icon(Icons.search, color: Color(0xFF9AA5AD)),
        filled: true,
        fillColor: MpColors.panel,
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _chipSection(
    String title,
    List<String> options,
    String selected,
    ValueChanged<String> onSelect,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5C6B75),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              // 화면 가장자리까지 스크롤되도록 부모 패딩만큼 확장
              clipBehavior: Clip.none,
              itemCount: options.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final on = options[i] == selected;
                return GestureDetector(
                  onTap: () => onSelect(options[i]),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    decoration: BoxDecoration(
                      color: on ? MpColors.ink : MpColors.panel,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Text(
                      options[i],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: on ? FontWeight.bold : FontWeight.normal,
                        color: on ? Colors.white : MpColors.ink,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountSort(int count) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '총 $count개의 상품',
            style: const TextStyle(fontSize: 13, color: MpColors.sub),
          ),
        ),
        PopupMenuButton<String>(
          initialValue: _sort,
          onSelected: (v) => setState(() => _sort = v),
          itemBuilder: (_) => _sorts
              .map((s) => PopupMenuItem(value: s, child: Text(s)))
              .toList(),
          child: Row(
            children: [
              const Icon(Icons.tune, size: 16, color: MpColors.sub),
              const SizedBox(width: 8),
              Text(
                _sort,
                style: const TextStyle(fontSize: 13, color: MpColors.icon),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 20,
                color: MpColors.sub,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard(MpProduct p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 215,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: MpColors.panel,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: p.imageUrl != null
                    ? Image.network(
                        p.imageUrl!,
                        fit: BoxFit.contain,
                        // 이미지가 없는 상품은 기본 아이콘을 보여준다.
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(
                            Icons.snowshoeing,
                            size: 80,
                            color: Color(0xFFB5BDC4),
                          ),
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.snowshoeing,
                          size: 80,
                          color: Color(0xFFB5BDC4),
                        ),
                      ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: IconButton(
                  onPressed: () => _toggleLike(p),
                  icon: Icon(
                    p.liked ? Icons.favorite : Icons.favorite_border,
                    color: p.liked ? MpColors.ink : const Color(0xFF9AA5AD),
                    size: 26,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.brandEn,
                style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.8,
                  color: MpColors.sub,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, color: MpColors.ink),
              ),
              const SizedBox(height: 4),
              Text(
                _won(p.price),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: MpColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                p.purpose.isEmpty
                    ? p.targetLabel
                    : '${p.targetLabel} · ${p.purpose}',
                style: const TextStyle(fontSize: 11, color: MpColors.sub),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
