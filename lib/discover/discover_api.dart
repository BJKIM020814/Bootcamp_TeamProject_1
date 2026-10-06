// Discover FastAPI client and response models.
//
// Run with --dart-define=DISCOVER_API_BASE_URL=http://127.0.0.1:8000 for
// Chrome. Android emulator and physical-device addresses are intentionally
// supplied by the run configuration, never stored with DB credentials.
import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../services/api_config.dart';

class DiscoverApiException implements Exception {
  const DiscoverApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class DiscoverProduct {
  const DiscoverProduct({
    required this.code,
    required this.name,
    required this.brand,
    required this.price,
    required this.sku,
    required this.gender,
    this.size,
    this.color,
    this.imagePath,
    this.colors = const [],
    this.sizes = const [],
    this.optionNotice,
    this.variants = const [],
  });

  final String code;
  final String name;
  final String brand;
  final int price;
  final String sku;
  final String gender;
  final int? size;
  final String? color;
  final String? imagePath;
  final List<String> colors;
  final List<int> sizes;
  final String? optionNotice;
  final List<DiscoverProduct> variants;

  factory DiscoverProduct.fromJson(
    Map<String, dynamic> json,
  ) => DiscoverProduct(
    code: json['product_code'] as String,
    name: json['name'] as String,
    brand: json['brand'] as String,
    price: json['price'] as int,
    sku: json['sku'] as String,
    gender: json['gender'] as String,
    size: json['size'] as int?,
    color: json['color'] as String?,
    imagePath: json['image_url'] as String?,
    colors: (json['available_colors'] as List? ?? const [])
        .map((value) => value as String)
        .toList(),
    sizes: (json['available_sizes'] as List? ?? const [])
        .map((value) => value as int)
        .toList(),
    optionNotice: json['option_notice'] as String?,
    variants: (json['variants'] as List? ?? const [])
        .map(
          (value) =>
              DiscoverProduct.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList(),
  );
}

class DiscoverFilters {
  const DiscoverFilters({
    required this.brands,
    required this.genders,
    required this.purposes,
  });

  final List<String> brands;
  final List<String> genders;
  final List<String> purposes;

  factory DiscoverFilters.fromJson(Map<String, dynamic> json) =>
      DiscoverFilters(
        brands: (json['brands'] as List).cast<String>(),
        genders: (json['genders'] as List).cast<String>(),
        purposes: (json['purposes'] as List).cast<String>(),
      );
}

class DiscoverBanner {
  const DiscoverBanner({required this.seq, required this.imagePath});

  final int seq;
  final String imagePath;

  factory DiscoverBanner.fromJson(Map<String, dynamic> json) => DiscoverBanner(
    seq: json['seq'] as int,
    imagePath: json['image_url'] as String,
  );
}

class PickupStore {
  const PickupStore({
    required this.id,
    required this.name,
    required this.address,
    required this.manager,
  });

  final int id;
  final String name;
  final String address;
  final String manager;

  factory PickupStore.fromJson(Map<String, dynamic> json) => PickupStore(
    id: json['seq'] as int,
    name: json['name'] as String,
    address: json['address'] as String,
    manager: json['manager'] as String,
  );
}

class DiscoverReviewList {
  const DiscoverReviewList({required this.items, required this.total});

  final List<Map<String, dynamic>> items;
  final int total;
}

class DiscoverApi {
  DiscoverApi({http.Client? client}) : _client = client ?? http.Client();

  static const _baseUrl = String.fromEnvironment(
    'DISCOVER_API_BASE_URL',
    defaultValue: ApiConfig.baseUrl,
  );
  final http.Client _client;
  void dispose() => _client.close();

  Future<DiscoverReviewList> reviews(String code) async {
    final data = await _getObject(
      '/api/v1/discover/products/${Uri.encodeComponent(code)}/reviews',
    );
    return DiscoverReviewList(
      items: (data['items'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
      total: data['total'] as int,
    );
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse(_baseUrl).resolve(path).replace(queryParameters: query);

  Future<Map<String, dynamic>> _getObject(
    String path, [
    Map<String, String>? query,
  ]) async {
    final http.Response response;
    try {
      response = await _client
          .get(_uri(path, query))
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      throw const DiscoverApiException('서버 응답 시간이 초과되었습니다. 다시 시도해 주세요.');
    } on SocketException {
      throw const DiscoverApiException('상품 서버에 연결할 수 없습니다. 네트워크를 확인해 주세요.');
    } on http.ClientException {
      throw const DiscoverApiException('상품 요청을 전송하지 못했습니다. 잠시 후 다시 시도해 주세요.');
    }

    dynamic decoded;
    try {
      decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw DiscoverApiException(
        '상품 서버 응답 형식을 확인할 수 없습니다.',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map && decoded['detail'] is Map
          ? decoded['detail']
          : decoded;
      final message = detail is Map ? detail['message'] as String? : null;
      throw DiscoverApiException(
        message ?? 'Discover 데이터를 불러오지 못했습니다.',
        statusCode: response.statusCode,
      );
    }
    if (decoded is! Map) {
      throw DiscoverApiException(
        '상품 서버 응답 형식이 올바르지 않습니다.',
        statusCode: response.statusCode,
      );
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<DiscoverFilters> filters() async =>
      DiscoverFilters.fromJson(await _getObject('/api/v1/discover/filters'));

  Future<List<DiscoverBanner>> banners() async {
    final data = await _getObject('/api/v1/discover/banners');
    return (data['items'] as List)
        .map(
          (item) =>
              DiscoverBanner.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<List<DiscoverProduct>> products({
    String? keyword,
    String? brand,
    String? gender,
    String? purpose,
  }) async {
    final query = <String, String>{'limit': '100'};
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    if (brand != null) query['brand'] = brand;
    if (gender != null) query['gender'] = gender;
    if (purpose != null) query['purpose'] = purpose;
    final data = await _getObject('/api/v1/discover/products', query);
    return (data['items'] as List)
        .map(
          (item) =>
              DiscoverProduct.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<DiscoverProduct> product(String code) async =>
      DiscoverProduct.fromJson(
        await _getObject(
          '/api/v1/discover/products/${Uri.encodeComponent(code)}',
        ),
      );

  Future<List<PickupStore>> pickupStores({String? keyword}) async {
    final data = await _getObject(
      '/api/v1/discover/pickup-stores',
      keyword == null || keyword.isEmpty ? null : {'keyword': keyword},
    );
    return (data['items'] as List)
        .map(
          (item) =>
              PickupStore.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  String? imageUrl(DiscoverProduct product) =>
      product.imagePath == null ? null : _uri(product.imagePath!).toString();

  /// API가 반환한 리뷰 이미지 경로를 Discover 서버 주소로 변환합니다.
  String? imageUrlFromPath(String? path) =>
      path == null || path.isEmpty ? null : _uri(path).toString();

  String bannerUrl(DiscoverBanner banner) => _uri(banner.imagePath).toString();
}
