import 'package:bootcamp_teamproject_1/order/orderApi.dart';
import 'package:get/get.dart';

/// 장바구니에 담긴 상품 한 줄을 표현한다. 값은 서버(/api/v1/order/cart) 응답이다.
class CartItem {
  CartItem({
    required this.id,
    required this.productCode,
    required this.brand,
    required this.name,
    required this.colorLabel,
    required this.size,
    required this.price,
    this.imageUrl,
    int quantity = 1,
    bool selected = true,
  }) : quantity = quantity.obs,
       selected = selected.obs;

  factory CartItem.fromLine(CartLine line) => CartItem(
    id: line.cartItemId,
    productCode: line.productCode,
    brand: line.brand,
    name: line.name,
    colorLabel: line.optionLabel,
    size: line.size == null ? '-' : '${line.size}mm',
    price: line.price,
    imageUrl: line.imageUrl,
    quantity: line.quantity,
    selected: line.selected,
  );

  final int id;
  final String productCode;
  final String brand;
  final String name;
  final String colorLabel;
  final String size;
  final int price;
  final String? imageUrl;
  final RxInt quantity;
  final RxBool selected;
}

/// 장바구니 전역 상태. 다른 화면(상품 상세 등)에서도
/// `CartController.to.addProduct(productCode)`로 담기 기능을 연결할 수 있다.
/// 모든 변경은 서버에 먼저 반영하고, 서버가 돌려준 장바구니로 화면을 갱신한다.
class CartController extends GetxController {
  static CartController get to => Get.isRegistered<CartController>()
      ? Get.find<CartController>()
      : Get.put(CartController(), permanent: true);

  final RxList<CartItem> items = <CartItem>[].obs;
  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();
  Future<bool>? _loadInFlight;

  bool get isEmpty => items.isEmpty;

  bool get isAllSelected =>
      items.isNotEmpty && items.every((item) => item.selected.value);

  int get selectedCount => items.where((item) => item.selected.value).length;

  int get selectedTotal => items
      .where((item) => item.selected.value)
      .fold(0, (sum, item) => sum + item.price * item.quantity.value);

  void _apply(CartData data) {
    items.assignAll(data.items.map(CartItem.fromLine));
    errorMessage.value = null;
  }

  /// 서버 요청을 실행하고 실패하면 errorMessage 에 남긴다. 성공 여부를 돌려준다.
  Future<bool> _run(Future<CartData> Function() request) async {
    isLoading.value = true;
    try {
      _apply(await request());
      return true;
    } catch (error) {
      errorMessage.value = error.toString();
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// 같은 화면 전환 중 중복 호출되더라도 서버 조회 하나만 공유한다.
  Future<bool> load() {
    final active = _loadInFlight;
    if (active != null) return active;
    late final Future<bool> request;
    request = _run(OrderApi.cart).whenComplete(() {
      if (identical(_loadInFlight, request)) _loadInFlight = null;
    });
    _loadInFlight = request;
    return request;
  }

  Future<bool> addProduct(String productCode, {int quantity = 1}) =>
      _run(() => OrderApi.addToCart(productCode, quantity: quantity));

  Future<bool> removeItem(int id) => _run(() => OrderApi.removeCartItem(id));

  Future<bool> removeSelected() => _run(OrderApi.removeSelected);

  Future<bool> toggleItem(int id) {
    final item = items.firstWhereOrNull((item) => item.id == id);
    if (item == null) return Future.value(false);
    return _run(
      () => OrderApi.updateCartItem(id, selected: !item.selected.value),
    );
  }

  Future<bool> toggleSelectAll(bool value) =>
      _run(() => OrderApi.selectAll(value));

  Future<bool> updateQuantity(int id, int delta) {
    final item = items.firstWhereOrNull((item) => item.id == id);
    if (item == null) return Future.value(false);
    final next = item.quantity.value + delta;
    if (next < 1 || next > 10) return Future.value(false);
    return _run(() => OrderApi.updateCartItem(id, quantity: next));
  }

  /// 장바구니에 있는 동안에만 실제 DB 옵션 행(색상·사이즈)을 바꾼다.
  Future<bool> updateProduct(int id, String productCode) =>
      _run(() => OrderApi.updateCartItem(id, productCode: productCode));

  /// 로그아웃 등으로 화면 상태만 비울 때 사용한다. (서버 장바구니는 유지)
  void clearLocal() {
    items.clear();
  }
}
