import 'dart:async';
import 'dart:convert';

import 'package:bootcamp_teamproject_1/services/api_client.dart';
import 'package:bootcamp_teamproject_1/user/authController.dart';
import 'package:http/http.dart' as http;

/// 주문(python/fastapi/order) FastAPI 호출 모음.
/// 서버 주소는 마이페이지와 같은 [ApiClient.baseUrl] 을 쓰고,
/// customer_id 는 로그인한 계정의 email([AuthController.customerId])이다.
class OrderApi {
  static const _prefix = '/api/v1/order';
  static const _timeout = Duration(seconds: 8);

  static String get _customerId {
    final id = AuthController.to.customerId.value;
    if (id == null || id.isEmpty) {
      throw ApiException('로그인이 필요합니다.', 401);
    }
    return id;
  }

  /// 서버가 돌려준 상대 경로(/api/v1/...)를 전체 주소로 바꾼다.
  static String? absoluteUrl(String? path) =>
      path == null ? null : ApiClient.absoluteUrl(path);

  static Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${ApiClient.baseUrl}$_prefix$path')
          .replace(queryParameters: query);

  static Map<String, String> get _q => {'customer_id': _customerId};

  static const _jsonHeaders = {
    'Content-Type': 'application/json; charset=utf-8',
  };

  static Future<dynamic> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(_timeout);
    } on TimeoutException {
      throw ApiException('서버 응답이 없습니다. 잠시 후 다시 시도해 주세요.');
    } catch (_) {
      throw ApiException('서버에 연결할 수 없습니다. 서버가 켜져 있는지 확인해 주세요.');
    }
    final text = utf8.decode(response.bodyBytes);
    final dynamic data = text.isEmpty ? null : jsonDecode(text);
    if (response.statusCode >= 400) {
      // 주문 API 오류: {"detail": {"code", "message"}} / 검증 오류: {"detail": [...]}
      final detail = data is Map ? data['detail'] : null;
      final message = detail is Map
          ? detail['message'] as String?
          : detail is String
          ? detail
          : null;
      throw ApiException(
        message ?? '요청을 처리하지 못했습니다. (${response.statusCode})',
        response.statusCode,
      );
    }
    return data;
  }

  static Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String>? query,
  ]) async =>
      Map<String, dynamic>.from(
        await _send(() => http.get(_uri(path, {..._q, ...?query}))) as Map,
      );

  static Future<Map<String, dynamic>> _write(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final payload = jsonEncode({'customer_id': _customerId, ...?body});
    final uri = _uri(path);
    final data = await _send(
      () => switch (method) {
        'POST' => http.post(uri, headers: _jsonHeaders, body: payload),
        'PUT' => http.put(uri, headers: _jsonHeaders, body: payload),
        _ => http.patch(uri, headers: _jsonHeaders, body: payload),
      },
    );
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> _delete(String path) async =>
      Map<String, dynamic>.from(
        await _send(() => http.delete(_uri(path, _q))) as Map,
      );

  // ---------- 수령 매장 ----------
  static Future<List<OrderStore>> pickupStores({String? keyword}) async {
    final query = keyword == null || keyword.isEmpty
        ? null
        : {'keyword': keyword};
    final data = await _send(() => http.get(_uri('/pickup-stores', query)));
    return ((data as Map)['items'] as List)
        .map((e) => OrderStore.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------- 장바구니 ----------
  static Future<CartData> cart() async => CartData.fromJson(await _get('/cart'));

  static Future<CartData> addToCart(String productCode, {int quantity = 1}) async =>
      CartData.fromJson(
        await _write('POST', '/cart/items', {
          'product_code': productCode,
          'quantity': quantity,
        }),
      );

  static Future<CartData> updateCartItem(
    int cartItemId, {
    int? quantity,
    bool? selected,
  }) async => CartData.fromJson(
    await _write('PATCH', '/cart/items/$cartItemId', {
      if (quantity != null) 'quantity': quantity,
      if (selected != null) 'selected': selected,
    }),
  );

  static Future<CartData> selectAll(bool selected) async => CartData.fromJson(
    await _write('PUT', '/cart/selection', {'selected': selected}),
  );

  static Future<CartData> removeCartItem(int cartItemId) async =>
      CartData.fromJson(await _delete('/cart/items/$cartItemId'));

  static Future<CartData> removeSelected() async =>
      CartData.fromJson(await _delete('/cart/items'));

  static Future<CartData> setPickupStore(int dealerSeq) async =>
      CartData.fromJson(
        await _write('PUT', '/cart/pickup-store', {'dealer_seq': dealerSeq}),
      );

  // ---------- 주문/결제 ----------
  static Future<CheckoutData> checkout() async =>
      CheckoutData.fromJson(await _get('/checkout'));

  static Future<OrderDetail> createOrder({
    required String ordererName,
    required String ordererPhone,
    required String paymentMethod,
    int? couponId,
    int? dealerSeq,
    required bool agreed,
  }) async => OrderDetail.fromJson(
    await _write('POST', '/orders', {
      'orderer_name': ordererName,
      'orderer_phone': ordererPhone,
      'payment_method': paymentMethod,
      'coupon_id': couponId,
      'dealer_seq': dealerSeq,
      'agreed': agreed,
    }),
  );

  /// status: all / in_progress / completed / cancelled
  static Future<List<OrderSummary>> orders({String status = 'all'}) async {
    final data = await _get('/orders', {'status': status, 'limit': '100'});
    return (data['items'] as List)
        .map((e) => OrderSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<OrderDetail> order(String orderNumber) async =>
      OrderDetail.fromJson(await _get('/orders/${Uri.encodeComponent(orderNumber)}'));

  static Future<OrderDetail> cancelOrder(String orderNumber) async =>
      OrderDetail.fromJson(
        await _write('POST', '/orders/${Uri.encodeComponent(orderNumber)}/cancel'),
      );

  // ---------- 매장 수령 ----------
  static Future<PickupCode> issuePickupCode(String orderNumber) async =>
      PickupCode.fromJson(
        await _write(
          'POST',
          '/orders/${Uri.encodeComponent(orderNumber)}/pickup-code',
        ),
      );

  static Future<OrderDetail> confirmPickup(String orderNumber, String code) async =>
      OrderDetail.fromJson(
        await _write('POST', '/orders/${Uri.encodeComponent(orderNumber)}/pickup', {
          'code': code,
        }),
      );

  // ---------- 교환/반품 ----------
  static Future<ClaimOptions> claimOptions(
    String orderNumber,
    int orderItemId,
  ) async => ClaimOptions.fromJson(
    await _get(
      '/orders/${Uri.encodeComponent(orderNumber)}/items/$orderItemId/claim-options',
    ),
  );

  /// claimType: EXCHANGE / RETURN. photos 는 이미지 바이트(최대 3장).
  static Future<ClaimRecord> createClaim({
    required String orderNumber,
    required int orderItemId,
    required String claimType,
    required String reason,
    required String detail,
    required int dealerSeq,
    int? requestedSize,
    List<List<int>> photos = const [],
  }) async => ClaimRecord.fromJson(
    await _write('POST', '/claims', {
      'order_number': orderNumber,
      'order_item_id': orderItemId,
      'claim_type': claimType,
      'reason': reason,
      'detail': detail,
      'dealer_seq': dealerSeq,
      'requested_size': requestedSize,
      'photos': [for (final bytes in photos) base64Encode(bytes)],
    }),
  );

  static Future<List<ClaimRecord>> claims({String? claimType}) async {
    final data = await _get(
      '/claims',
      claimType == null ? null : {'claim_type': claimType},
    );
    return (data['items'] as List)
        .map((e) => ClaimRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<ClaimRecord> claim(int claimId) async =>
      ClaimRecord.fromJson(await _get('/claims/$claimId'));
}

// ---------- 공통 표시 ----------
String formatWon(int value) {
  final sign = value < 0 ? '-' : '';
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    if (i > 0 && remaining % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '$sign₩$buffer';
}

/// 2026.10.01
String formatDate(DateTime date) =>
    '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

DateTime _date(dynamic value) => DateTime.parse(value as String);
DateTime? _dateOrNull(dynamic value) =>
    value == null ? null : DateTime.parse(value as String);

// ---------- 모델 ----------
class OrderStore {
  const OrderStore({
    required this.seq,
    required this.name,
    required this.address,
    required this.manager,
    this.latitude,
    this.longitude,
  });

  final int seq;
  final String name;
  final String address;
  final String manager;
  final double? latitude;
  final double? longitude;

  factory OrderStore.fromJson(Map<String, dynamic> json) => OrderStore(
    seq: json['seq'] as int,
    name: json['name'] as String,
    address: json['address'] as String,
    manager: json['manager'] as String,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
  );

  static OrderStore? maybe(dynamic json) =>
      json == null ? null : OrderStore.fromJson(json as Map<String, dynamic>);
}

class CartLine {
  const CartLine({
    required this.cartItemId,
    required this.productCode,
    required this.brand,
    required this.name,
    required this.optionLabel,
    required this.size,
    required this.price,
    required this.quantity,
    required this.selected,
    this.imageUrl,
  });

  final int cartItemId;
  final String productCode;
  final String brand;
  final String name;
  final String optionLabel;
  final int? size;
  final int price;
  final int quantity;
  final bool selected;
  final String? imageUrl;

  factory CartLine.fromJson(Map<String, dynamic> json) => CartLine(
    cartItemId: json['cart_item_id'] as int,
    productCode: json['product_code'] as String,
    brand: json['brand'] as String,
    name: json['name'] as String,
    optionLabel: json['option_label'] as String,
    size: json['size'] as int?,
    price: json['price'] as int,
    quantity: json['quantity'] as int,
    selected: json['selected'] as bool,
    imageUrl: OrderApi.absoluteUrl(json['image_url'] as String?),
  );
}

class CartData {
  const CartData({required this.items, this.pickupStore});

  final List<CartLine> items;
  final OrderStore? pickupStore;

  factory CartData.fromJson(Map<String, dynamic> json) => CartData(
    items: (json['items'] as List)
        .map((e) => CartLine.fromJson(e as Map<String, dynamic>))
        .toList(),
    pickupStore: OrderStore.maybe(json['pickup_store']),
  );
}

class CheckoutCoupon {
  const CheckoutCoupon({
    required this.couponId,
    required this.name,
    required this.discountAmount,
  });

  final int couponId;
  final String name;
  final int discountAmount;

  factory CheckoutCoupon.fromJson(Map<String, dynamic> json) => CheckoutCoupon(
    couponId: json['coupon_id'] as int,
    name: json['name'] as String,
    discountAmount: json['discount_amount'] as int,
  );
}

class CheckoutData {
  const CheckoutData({
    required this.items,
    required this.subtotal,
    required this.paymentMethods,
    required this.defaultPayment,
    required this.coupons,
    this.pickupStore,
  });

  final List<CartLine> items;
  final int subtotal;
  final List<String> paymentMethods;
  final String defaultPayment;
  final List<CheckoutCoupon> coupons;
  final OrderStore? pickupStore;

  factory CheckoutData.fromJson(Map<String, dynamic> json) => CheckoutData(
    items: (json['items'] as List)
        .map((e) => CartLine.fromJson(e as Map<String, dynamic>))
        .toList(),
    subtotal: json['subtotal'] as int,
    paymentMethods: List<String>.from(json['payment_methods'] as List),
    defaultPayment: json['default_payment'] as String,
    coupons: (json['coupons'] as List)
        .map((e) => CheckoutCoupon.fromJson(e as Map<String, dynamic>))
        .toList(),
    pickupStore: OrderStore.maybe(json['pickup_store']),
  );
}

class OrderLine {
  const OrderLine({
    required this.orderItemId,
    required this.productCode,
    required this.brand,
    required this.name,
    required this.optionLabel,
    required this.size,
    required this.price,
    required this.quantity,
    this.imageUrl,
  });

  final int orderItemId;
  final String productCode;
  final String brand;
  final String name;
  final String optionLabel;
  final int? size;
  final int price;
  final int quantity;
  final String? imageUrl;

  String get sizeLabel => size == null ? '-' : '${size}mm';

  factory OrderLine.fromJson(Map<String, dynamic> json) => OrderLine(
    orderItemId: json['order_item_id'] as int,
    productCode: json['product_code'] as String,
    brand: json['brand'] as String,
    name: json['name'] as String,
    optionLabel: json['option_label'] as String,
    size: json['size'] as int?,
    price: json['price'] as int,
    quantity: json['quantity'] as int,
    imageUrl: OrderApi.absoluteUrl(json['image_url'] as String?),
  );
}

class OrderSummary {
  const OrderSummary({
    required this.orderNumber,
    required this.orderedAt,
    required this.status,
    required this.statusLabel,
    required this.statusGroup,
    required this.stageIndex,
    required this.storeName,
    required this.paidAmount,
    required this.items,
  });

  final String orderNumber;
  final DateTime orderedAt;
  final String status;
  final String statusLabel;

  /// in_progress / completed / cancelled
  final String statusGroup;

  /// 0=결제, 1=준비, 2=이동, 3=수령
  final int stageIndex;
  final String storeName;
  final int paidAmount;
  final List<OrderLine> items;

  factory OrderSummary.fromJson(Map<String, dynamic> json) => OrderSummary(
    orderNumber: json['order_number'] as String,
    orderedAt: _date(json['ordered_at']),
    status: json['status'] as String,
    statusLabel: json['status_label'] as String,
    statusGroup: json['status_group'] as String,
    stageIndex: json['stage_index'] as int,
    storeName: json['store_name'] as String,
    paidAmount: json['paid_amount'] as int,
    items: (json['items'] as List)
        .map((e) => OrderLine.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class TimelineStep {
  const TimelineStep(this.label, this.done, this.current);

  final String label;
  final bool done;
  final bool current;
}

class OrderDetail extends OrderSummary {
  const OrderDetail({
    required super.orderNumber,
    required super.orderedAt,
    required super.status,
    required super.statusLabel,
    required super.statusGroup,
    required super.stageIndex,
    required super.storeName,
    required super.paidAmount,
    required super.items,
    required this.ordererName,
    required this.ordererPhone,
    required this.paymentMethod,
    required this.subtotal,
    required this.discount,
    required this.couponName,
    required this.storeAddress,
    required this.pickupStore,
    required this.timeline,
    required this.pickupCompleted,
    required this.pickedUp,
    required this.readyAt,
    required this.pickupDueAt,
    required this.canCancel,
    required this.canClaim,
  });

  final String ordererName;
  final String ordererPhone;
  final String paymentMethod;
  final int subtotal;
  final int discount;
  final String? couponName;
  final String storeAddress;
  final OrderStore? pickupStore;
  final List<TimelineStep> timeline;

  /// Flutter PickupStage.completed 여부 (수령 준비 완료 이후)
  final bool pickupCompleted;
  final bool pickedUp;
  final DateTime? readyAt;
  final DateTime? pickupDueAt;
  final bool canCancel;
  final bool canClaim;

  bool get isCancelled => status == 'CANCELLED';

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    final summary = OrderSummary.fromJson(json);
    return OrderDetail(
      orderNumber: summary.orderNumber,
      orderedAt: summary.orderedAt,
      status: summary.status,
      statusLabel: summary.statusLabel,
      statusGroup: summary.statusGroup,
      stageIndex: summary.stageIndex,
      storeName: summary.storeName,
      paidAmount: summary.paidAmount,
      items: summary.items,
      ordererName: json['orderer_name'] as String,
      ordererPhone: json['orderer_phone'] as String,
      paymentMethod: json['payment_method'] as String,
      subtotal: json['subtotal'] as int,
      discount: json['discount'] as int,
      couponName: json['coupon_name'] as String?,
      storeAddress: json['store_address'] as String,
      pickupStore: OrderStore.maybe(json['pickup_store']),
      timeline: [
        for (final step in json['timeline'] as List)
          TimelineStep(
            step['label'] as String,
            step['done'] as bool,
            step['current'] as bool,
          ),
      ],
      pickupCompleted: json['pickup_stage'] == 'completed',
      pickedUp: json['picked_up'] as bool,
      readyAt: _dateOrNull(json['ready_at']),
      pickupDueAt: _dateOrNull(json['pickup_due_at']),
      canCancel: json['can_cancel'] as bool,
      canClaim: json['can_claim'] as bool,
    );
  }
}

class PickupCode {
  const PickupCode({
    required this.code,
    required this.qrPayload,
    required this.expiresAt,
    this.visitFrom,
    this.visitUntil,
  });

  final String code;
  final String qrPayload;
  final DateTime expiresAt;
  final DateTime? visitFrom;
  final DateTime? visitUntil;

  factory PickupCode.fromJson(Map<String, dynamic> json) => PickupCode(
    code: json['code'] as String,
    qrPayload: json['qr_payload'] as String,
    expiresAt: _date(json['expires_at']),
    visitFrom: _dateOrNull(json['visit_from']),
    visitUntil: _dateOrNull(json['visit_until']),
  );
}

class ClaimOptions {
  const ClaimOptions({
    required this.item,
    required this.eligible,
    required this.notice,
    required this.reasons,
    required this.availableSizes,
    required this.stores,
    required this.defaultDealerSeq,
    required this.refundAmount,
    required this.maxPhotos,
  });

  final OrderLine item;
  final bool eligible;
  final String? notice;
  final List<String> reasons;
  final List<int> availableSizes;
  final List<OrderStore> stores;
  final int defaultDealerSeq;
  final int refundAmount;
  final int maxPhotos;

  factory ClaimOptions.fromJson(Map<String, dynamic> json) => ClaimOptions(
    item: OrderLine.fromJson(json['item'] as Map<String, dynamic>),
    eligible: json['eligible'] as bool,
    notice: json['notice'] as String?,
    reasons: List<String>.from(json['reasons'] as List),
    availableSizes: List<int>.from(json['available_sizes'] as List),
    stores: (json['stores'] as List)
        .map((e) => OrderStore.fromJson(e as Map<String, dynamic>))
        .toList(),
    defaultDealerSeq: json['default_dealer_seq'] as int,
    refundAmount: json['refund_amount'] as int,
    maxPhotos: json['max_photos'] as int,
  );
}

class ClaimRecord {
  const ClaimRecord({
    required this.claimId,
    required this.claimType,
    required this.claimTypeLabel,
    required this.requestedAt,
    required this.orderNumber,
    required this.item,
    required this.storeName,
    required this.reason,
    required this.detail,
    required this.requestedSize,
    required this.refundAmount,
    required this.statusLabel,
    required this.stageIndex,
    required this.photoUrls,
  });

  final int claimId;

  /// EXCHANGE / RETURN
  final String claimType;
  final String claimTypeLabel;
  final DateTime requestedAt;
  final String orderNumber;
  final OrderLine item;
  final String storeName;
  final String reason;
  final String detail;
  final int? requestedSize;
  final int refundAmount;
  final String statusLabel;

  /// 0=신청 접수, 1=본사 확인, 2=방문, 3=완료
  final int stageIndex;
  final List<String> photoUrls;

  bool get isExchange => claimType == 'EXCHANGE';

  factory ClaimRecord.fromJson(Map<String, dynamic> json) => ClaimRecord(
    claimId: json['claim_id'] as int,
    claimType: json['claim_type'] as String,
    claimTypeLabel: json['claim_type_label'] as String,
    requestedAt: _date(json['requested_at']),
    orderNumber: json['order_number'] as String,
    item: OrderLine.fromJson(json['item'] as Map<String, dynamic>),
    storeName: json['store_name'] as String,
    reason: json['reason'] as String,
    detail: json['detail'] as String,
    requestedSize: json['requested_size'] as int?,
    refundAmount: json['refund_amount'] as int,
    statusLabel: json['status_label'] as String,
    stageIndex: json['stage_index'] as int,
    photoUrls: [
      for (final url in json['photo_urls'] as List)
        OrderApi.absoluteUrl(url as String)!,
    ],
  );
}
