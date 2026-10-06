import 'package:bootcamp_teamproject_1/discover/discover_api.dart';
import 'package:bootcamp_teamproject_1/common/fitpick_snackbar.dart';
import 'package:bootcamp_teamproject_1/common/review_image_view.dart';
import 'package:bootcamp_teamproject_1/order/cartController.dart';
import 'package:bootcamp_teamproject_1/order/cartPage.dart';
import 'package:bootcamp_teamproject_1/order/checkoutPage.dart';
import 'package:bootcamp_teamproject_1/services/mypage_api.dart';
import 'package:bootcamp_teamproject_1/user/authController.dart';
import 'package:bootcamp_teamproject_1/user/loginpage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 목업의 갤러리·옵션·상세 탭·하단 구매 바를 실제 DB 상품 데이터로 구성한다.
class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({
    super.key,
    required this.productCode,
    this.cartItemId,
  });

  final String productCode;

  /// 값이 있으면 장바구니 옵션 편집 화면으로 동작하며 구매 주문을 만들지 않는다.
  final int? cartItemId;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final DiscoverApi _api = DiscoverApi();
  late Future<DiscoverProduct> _productFuture;
  Future<DiscoverReviewList>? _reviewsFuture;
  int? _reviewCount;
  String? _selectedColor;
  int? _selectedSize;
  int _sectionIndex = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _productFuture = _api.product(widget.productCode);
    _recordView();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  /// 로그인 계정의 최근 본 상품 목록에 실제 상품 코드를 기록한다.
  Future<void> _recordView() async {
    final email = AuthController.to.customerId.value;
    if (email == null) return;
    try {
      await MyPageApi.recordView(email, widget.productCode);
    } catch (_) {
      // 기록 실패는 상품 상세 조회/구매 흐름을 막지 않는다.
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('상품 상세', style: TextStyle(fontWeight: FontWeight.w900)),
      actions: [
        IconButton(
          tooltip: '장바구니 보기',
          onPressed: _openCart,
          icon: const Icon(Icons.shopping_bag_outlined),
        ),
      ],
    ),
    body: FutureBuilder<DiscoverProduct>(
      future: _productFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _errorState(snapshot.error);
        }
        return _content(snapshot.data!);
      },
    ),
  );

  Widget _errorState(Object? error) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 42),
          const SizedBox(height: 12),
          Text('$error', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              final nextProduct = _api.product(widget.productCode);
              setState(() => _productFuture = nextProduct);
            },
            child: const Text('상품 다시 불러오기'),
          ),
        ],
      ),
    ),
  );

  Widget _content(DiscoverProduct product) {
    final variants = product.variants.isEmpty ? [product] : product.variants;
    final colors = product.colors.isNotEmpty
        ? product.colors
        : variants
              .map((variant) => variant.color)
              .whereType<String>()
              .toSet()
              .toList();
    final color = colors.contains(_selectedColor)
        ? _selectedColor
        : (product.color ?? (colors.isEmpty ? null : colors.first));
    final sizes =
        variants
            .where((variant) => color == null || variant.color == color)
            .map((variant) => variant.size)
            .whereType<int>()
            .where((size) => size > 0)
            .toSet()
            .toList()
          ..sort();
    final size = sizes.contains(_selectedSize)
        ? _selectedSize
        : (product.size != null && sizes.contains(product.size)
              ? product.size
              : (sizes.isEmpty ? null : sizes.first));
    final selected = _matchingVariant(variants, color, size);
    final purchasable =
        selected != null && size != null && sizes.contains(size);
    final gallery = _galleryVariants(variants, color, selected ?? product);
    _reviewsFuture ??= _fetchReviews();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              _buildGallery(gallery),
              const SizedBox(height: 20),
              Text(
                '${product.brand}  /  ${product.sku}',
                style: const TextStyle(
                  color: Color(0xFF777068),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                product.name,
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '₩${selected?.price ?? product.price}',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '대상: ${product.gender}',
                style: const TextStyle(color: Color(0xFF777068)),
              ),
              const SizedBox(height: 24),
              _buildOptionHeading('색상 선택', color),
              const SizedBox(height: 10),
              _buildColorOptions(colors, color),
              const SizedBox(height: 20),
              _buildOptionHeading('구매 사이즈', size == null ? null : '$size mm'),
              const SizedBox(height: 10),
              _buildSizeOptions(sizes, size),
              if (product.optionNotice != null) ...[
                const SizedBox(height: 8),
                Text(
                  product.optionNotice!,
                  style: const TextStyle(
                    color: Color(0xFF8A5C2D),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _selectionSummary(color, size),
              const SizedBox(height: 24),
              _buildSectionTabs(),
              const SizedBox(height: 16),
              _buildSectionContent(product, color, size),
            ],
          ),
        ),
        _buildPurchaseBar(selected ?? product, purchasable),
      ],
    );
  }

  List<DiscoverProduct> _galleryVariants(
    List<DiscoverProduct> variants,
    String? color,
    DiscoverProduct selected,
  ) {
    // 선택 조합과 같은 실제 상품 행의 이미지 하나를 사용해 색상 변경 즉시 사진도 바뀌게 한다.
    final exact = variants.where(
      (variant) =>
          (color == null || variant.color == color) &&
          variant.code == selected.code,
    );
    final chosen = exact.isNotEmpty ? exact.first : selected;
    return [_api.imageUrl(chosen) == null ? selected : chosen];
  }

  DiscoverProduct? _matchingVariant(
    List<DiscoverProduct> variants,
    String? color,
    int? size,
  ) {
    if (size == null) return null;
    final matches = variants.where(
      (variant) =>
          variant.size == size && (color == null || variant.color == color),
    );
    return matches.length == 1 ? matches.first : null;
  }

  Widget _buildGallery(List<DiscoverProduct> images) => Column(
    children: [
      SizedBox(
        height: 300,
        child: PageView.builder(
          itemCount: images.length,
          itemBuilder: (context, index) {
            final url = _api.imageUrl(images[index]);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F3F1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: url == null
                    ? const Center(child: Icon(Icons.image_outlined, size: 64))
                    : Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(Icons.broken_image_outlined, size: 64),
                        ),
                      ),
              ),
            );
          },
        ),
      ),
      if (images.length > 1) ...[
        const SizedBox(height: 8),
        Text(
          '사진 ${images.length}장 · 좌우로 넘겨보기',
          style: const TextStyle(fontSize: 11, color: Color(0xFF918981)),
        ),
      ],
    ],
  );

  Widget _buildOptionHeading(String title, String? value) => Row(
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      const Spacer(),
      if (value != null)
        Text(
          '$value 선택됨',
          style: const TextStyle(fontSize: 12, color: Color(0xFF777068)),
        ),
    ],
  );

  Widget _buildColorOptions(List<String> colors, String? selected) {
    if (colors.isEmpty) {
      return const Text(
        'DB에 등록된 색상 옵션이 없습니다.',
        style: TextStyle(color: Color(0xFF777068)),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final color in colors)
          ChoiceChip(
            label: Text(color),
            selected: selected == color,
            onSelected: (_) => setState(() {
              _selectedColor = color;
              _selectedSize = null;
            }),
          ),
      ],
    );
  }

  Widget _buildSizeOptions(List<int> sizes, int? selected) {
    if (sizes.isEmpty) {
      return const Text(
        'DB에 등록된 구매 사이즈가 없습니다.',
        style: TextStyle(color: Color(0xFF777068)),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final size in sizes)
          ChoiceChip(
            label: Text('$size mm'),
            selected: selected == size,
            onSelected: (_) => setState(() => _selectedSize = size),
          ),
      ],
    );
  }

  Widget _selectionSummary(String? color, int? size) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F2ED),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.checkroom_outlined,
          size: 18,
          color: Color(0xFF5D5751),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            '선택한  ${color ?? '색상 미선택'}  ·  ${size == null ? '사이즈 미선택' : '$size mm'}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF5D5751)),
          ),
        ),
      ],
    ),
  );

  Widget _buildSectionTabs() => Row(
    children: [
      _sectionTab('상품 정보', 0),
      _sectionTab(_reviewCount == null ? '구매 리뷰' : '구매 리뷰 ($_reviewCount)', 1),
      _sectionTab('교환 · 반품', 2),
    ],
  );

  Widget _sectionTab(String title, int index) => Expanded(
    child: InkWell(
      onTap: () {
        setState(() => _sectionIndex = index);
        if (index == 1) _reviewsFuture ??= _fetchReviews();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: _sectionIndex == index
                  ? const Color(0xFF272A2D)
                  : const Color(0xFFE4E0DB),
              width: _sectionIndex == index ? 2 : 1,
            ),
          ),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: _sectionIndex == index
                  ? FontWeight.w900
                  : FontWeight.w500,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildSectionContent(
    DiscoverProduct product,
    String? color,
    int? size,
  ) => switch (_sectionIndex) {
    0 => _productInformation(product, color, size),
    1 => _reviewSection(),
    _ => _exchangeReturnSection(),
  };

  Widget _productInformation(
    DiscoverProduct product,
    String? color,
    int? size,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '상품 정보',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 10),
      _infoRow('브랜드', product.brand),
      _infoRow('상품명', product.name),
      _infoRow('상품 코드', product.code),
      _infoRow('상품 식별 코드', product.sku),
      _infoRow('대상', product.gender),
      if (color != null) _infoRow('색상', color),
      if (size != null) _infoRow('사이즈', '$size mm'),
    ],
  );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF777068), fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  Future<DiscoverReviewList> _fetchReviews() async {
    final result = await _api.reviews(widget.productCode);
    if (mounted && _reviewCount != result.total) {
      setState(() => _reviewCount = result.total);
    }
    return result;
  }

  void _reloadReviews() {
    setState(() {
      _reviewCount = null;
      _reviewsFuture = _fetchReviews();
    });
  }

  Widget _reviewSection() => FutureBuilder<DiscoverReviewList>(
    future: _reviewsFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          ),
        );
      }
      if (snapshot.hasError) {
        return Center(
          child: TextButton(
            onPressed: () {
              _reloadReviews();
            },
            child: const Text('리뷰 다시 불러오기'),
          ),
        );
      }
      final reviewList = snapshot.data;
      final reviews = reviewList?.items ?? const <Map<String, dynamic>>[];
      if (reviews.isEmpty) return const Text('등록된 구매 리뷰가 없습니다.');
      final ratings = reviews
          .map((review) => num.tryParse('${review['rating']}') ?? 0)
          .toList();
      final average = ratings.reduce((a, b) => a + b) / ratings.length;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, color: Color(0xFFE1A63A)),
              const SizedBox(width: 4),
              Text(
                average.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '리뷰 ${reviewList?.total ?? reviews.length}개',
                style: const TextStyle(color: Color(0xFF777068)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final review in reviews) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ReviewImageView(
                    imageUrl: _api.imageUrlFromPath(
                      review['image_url']?.toString(),
                    ),
                    height: 180,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFE1A63A),
                        size: 19,
                      ),
                      const SizedBox(width: 4),
                      Text('${review['rating'] ?? '-'}점'),
                      const SizedBox(width: 10),
                      Text(
                        '${review['fit'] ?? ''} · ${review['created_at'] ?? ''}',
                        style: const TextStyle(color: Color(0xFF777068)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('${review['content'] ?? ''}'),
                ],
              ),
            ),
          ],
        ],
      );
    },
  );

  Widget _exchangeReturnSection() => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '교환 · 반품',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
      ),
      SizedBox(height: 10),
      Text(
        '주문한 상품의 수령이 완료되면 주문내역에서 교환 또는 반품을 신청할 수 있습니다. 신청 가능 여부와 진행 상태는 주문 상세에서 확인해 주세요.',
        style: TextStyle(fontSize: 12, height: 1.6, color: Color(0xFF6E675F)),
      ),
    ],
  );

  Widget _buildPurchaseBar(DiscoverProduct selected, bool hasSize) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEDEAE6))),
      ),
      child: widget.cartItemId != null
          ? SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy || !hasSize
                    ? null
                    : () => _updateCartOption(selected),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF272A2D),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(_busy ? '변경 중…' : '선택한 옵션으로 변경'),
              ),
            )
          : Row(
              children: [
                IconButton(
                  tooltip: '장바구니에 담기',
                  onPressed: _busy || !hasSize
                      ? null
                      : () => _addToCart(selected, buyNow: false),
                  icon: const Icon(Icons.shopping_bag_outlined),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy || !hasSize
                        ? null
                        : () => _addToCart(selected, buyNow: true),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF272A2D),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(
                      _busy
                          ? '처리 중…'
                          : (hasSize
                                ? '${_selectedSize ?? selected.size}mm 바로 구매'
                                : '구매 옵션을 확인할 수 없습니다'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
    ),
  );

  Future<void> _updateCartOption(DiscoverProduct product) async {
    final cartItemId = widget.cartItemId;
    if (cartItemId == null) return;
    setState(() => _busy = true);
    try {
      final cart = CartController.to;
      if (!await cart.updateProduct(cartItemId, product.code)) {
        _showMessage(cart.errorMessage.value ?? '옵션 변경에 실패했습니다.');
        return;
      }
      if (mounted) {
        showFitpickSnackbar('색상과 사이즈를 변경했습니다.', title: '장바구니');
        Get.back();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 서버 장바구니에 선택 상품을 저장하고, 바로 구매면 해당 상품만 선택해 결제로 이동한다.
  Future<void> _addToCart(
    DiscoverProduct product, {
    required bool buyNow,
  }) async {
    if (!AuthController.to.isLoggedIn.value) {
      await Get.to(() => const LoginPage());
      return;
    }
    setState(() => _busy = true);
    final cart = CartController.to;
    try {
      if (!await cart.addProduct(product.code)) {
        _showMessage(cart.errorMessage.value ?? '장바구니에 담지 못했습니다.');
        return;
      }
      if (buyNow) {
        if (!await cart.toggleSelectAll(false)) {
          _showMessage(cart.errorMessage.value ?? '결제 상품 선택에 실패했습니다.');
          return;
        }
        final item = cart.items.firstWhereOrNull(
          (entry) => entry.productCode == product.code,
        );
        if (item == null || !await cart.toggleItem(item.id)) {
          _showMessage(cart.errorMessage.value ?? '결제할 상품을 선택하지 못했습니다.');
          return;
        }
        if (mounted) Get.to(() => const Checkoutpage());
      } else if (mounted) {
        Get.to(() => const Cartpage());
      }
    } catch (error) {
      _showMessage('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    showFitpickSnackbar(message);
  }

  void _openCart() {
    if (!AuthController.to.isLoggedIn.value) {
      Get.to(() => const LoginPage());
      return;
    }
    Get.to(() => const Cartpage());
  }
}
