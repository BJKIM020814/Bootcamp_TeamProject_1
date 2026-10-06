import 'package:get/get.dart';

/// 장바구니에 담긴 상품 한 줄을 표현한다.
class CartItem {
  CartItem({
    required this.id,
    required this.brand,
    required this.name,
    required this.colorLabel,
    required this.size,
    required this.price,
    this.imagePath,
    int quantity = 1,
    bool selected = true,
  }) : quantity = quantity.obs,
       selected = selected.obs;

  final String id;
  final String brand;
  final String name;
  final String colorLabel;
  final String size;
  final int price;
  final String? imagePath;
  final RxInt quantity;
  final RxBool selected;
}

/// 앱 화면 사이에서 공유하는 장바구니 데모 상태.
/// 현재 서버 장바구니 테이블/API가 연결되기 전까지 변경 내용은 메모리에만 있다.
class CartController extends GetxController {
  static CartController get to => Get.isRegistered<CartController>()
      ? Get.find<CartController>()
      : Get.put(CartController(), permanent: true);

  final RxList<CartItem> items = <CartItem>[].obs;

  final RxString storeName = '강남 스토어'.obs;
  final RxString storeAddress = '서울 강남구 강남역 인근 · 예시 위치'.obs;

  bool get isEmpty => items.isEmpty;

  bool get isAllSelected =>
      items.isNotEmpty && items.every((item) => item.selected.value);

  int get selectedCount => items.where((item) => item.selected.value).length;

  int get selectedTotal => items
      .where((item) => item.selected.value)
      .fold(0, (sum, item) => sum + item.price * item.quantity.value);

  void addItem(CartItem item) => items.add(item);

  void removeItem(String id) => items.removeWhere((item) => item.id == id);

  void removeSelected() => items.removeWhere((item) => item.selected.value);

  void toggleItem(String id) {
    final item = items.firstWhereOrNull((item) => item.id == id);
    if (item != null) item.selected.value = !item.selected.value;
  }

  void toggleSelectAll(bool value) {
    for (final item in items) {
      item.selected.value = value;
    }
    items.refresh();
  }

  void updateQuantity(String id, int delta) {
    final item = items.firstWhereOrNull((item) => item.id == id);
    if (item == null) return;
    final next = item.quantity.value + delta;
    if (next < 1) return;
    item.quantity.value = next;
  }

  void updateStore(String name, String address) {
    storeName.value = name;
    storeAddress.value = address;
  }

  /// 비어 있는 장바구니 화면의 UI 확인을 위한 목업 데이터를 한 번 추가한다.
  void seedSampleData() {
    if (items.isNotEmpty) return;
    items.addAll([
      CartItem(
        id: 'sample-1',
        brand: 'NEW BALANCE',
        name: '530',
        colorLabel: '화이트 / 네추럴 인디고 · 270mm',
        size: '270mm',
        price: 129000,
      ),
      CartItem(
        id: 'sample-2',
        brand: 'NIKE',
        name: "에어 포스 1 '07",
        colorLabel: '화이트 / 화이트 · 270mm',
        size: '270mm',
        price: 119000,
        selected: false,
      ),
    ]);
  }
}
