import 'package:bootcamp_teamproject_1/discover/discover_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

const _naverMapClientId = String.fromEnvironment('NAVER_MAP_CLIENT_ID');

/// 본사 발송 상품의 픽업 지점만 조회한다. 대리점 재고·판매 가능 여부는 판단하지 않는다.
class StoreSelectionPage extends StatefulWidget {
  const StoreSelectionPage({
    super.key,
    this.productCode,
    this.color,
    this.size,
  });
  final String? productCode;
  final String? color;
  final int? size;
  @override
  State<StoreSelectionPage> createState() => _StoreSelectionPageState();
}

class _StoreSelectionPageState extends State<StoreSelectionPage> {
  // 상품 코드/옵션은 호출부에서 전달되지만, 현재 화면은 전체 픽업 지점만 조회한다.
  final _api = DiscoverApi();
  final _search = TextEditingController();
  late Future<List<PickupStore>> _stores;
  PickupStore? _selected;
  Object? _loadError;
  final Map<int, GlobalKey> _storeTileKeys = {};
  @override
  void initState() {
    super.initState();
    _stores = _loadStores();
  }

  @override
  void dispose() {
    _api.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<List<PickupStore>> _loadStores() async {
    try {
      return await _api.pickupStores(keyword: _search.text);
    } catch (error) {
      _loadError = error;
      rethrow;
    }
  }

  void _reload() => setState(() {
    // 새 검색 결과에서 사라진 매장을 이전 선택값으로 확정하지 않는다.
    _selected = null;
    _loadError = null;
    _stores = _loadStores();
  });

  /// 지도 마커 또는 목록에서 매장을 선택하고, 지도 선택이면 해당 행을 보여준다.
  void _selectStore(PickupStore? store, {bool revealInList = false}) {
    setState(() => _selected = store);
    if (store == null || !revealInList) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tileContext = _storeTileKeys[store.id]?.currentContext;
      if (tileContext != null) {
        Scrollable.ensureVisible(
          tileContext,
          alignment: 0.5,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('매장 찾기', style: TextStyle(fontWeight: FontWeight.w900)),
      centerTitle: true,
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.all(20),
      child: FilledButton(
        onPressed: _selected == null
            ? null
            : () => Navigator.of(context).pop(_selected),
        child: Text(
          _selected == null ? '수령 매장을 선택하세요' : '${_selected!.name} 선택',
        ),
      ),
    ),
    body: FutureBuilder<List<PickupStore>>(
      future: _stores,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_loadError ?? snap.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _reload,
                    child: const Text('매장 목록 다시 시도'),
                  ),
                ],
              ),
            ),
          );
        }
        final stores = snap.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          children: [
            if (widget.productCode != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F1EE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '선택 상품: ${widget.productCode} · ${widget.color ?? '색상 미지정'} · ${widget.size == null ? '사이즈 미지정' : '${widget.size} mm'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _search,
              onSubmitted: (_) => _reload(),
              decoration: InputDecoration(
                hintText: '매장 또는 지역 검색',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: const Color(0xFFF3F1EE),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '매장은 본사 발송 상품의 수령 지점입니다. 판매 재고로 구매 가능 여부를 판단하지 않습니다.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF6E675F),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            _buildMap(stores),
            const SizedBox(height: 18),
            if (stores.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 50),
                child: Center(child: Text('등록된 수령 매장이 없습니다.')),
              )
            else
              RadioGroup<PickupStore>(
                groupValue: _selected,
                onChanged: (store) => _selectStore(store),
                child: Column(
                  children: [
                    for (final store in stores)
                      Card(
                        key: _storeTileKeys.putIfAbsent(
                          store.id,
                          GlobalKey.new,
                        ),
                        child: RadioListTile<PickupStore>(
                          value: store,
                          title: Text(
                            store.name,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: Text(
                            '${store.address}\n담당자: ${store.manager}',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    ),
  );

  /// Naver Dynamic Map에 DB 좌표가 유효한 픽업 매장만 표시한다.
  Widget _buildMap(List<PickupStore> stores) {
    if (kIsWeb) {
      return _mapNotice('네이버 지도는 iOS·Android 앱에서 확인할 수 있습니다.');
    }
    if (_naverMapClientId.trim().isEmpty) {
      return _mapNotice(
        '.env에 NAVER_MAP_CLIENT_ID를 설정한 뒤 tool/run_flutter_with_env.sh로 실행해 주세요.',
      );
    }
    final locatedStores = stores.where((store) {
      final latitude = store.latitude;
      final longitude = store.longitude;
      return latitude != null &&
          longitude != null &&
          latitude >= -90 &&
          latitude <= 90 &&
          longitude >= -180 &&
          longitude <= 180;
    }).toList();
    if (locatedStores.isEmpty) {
      return _mapNotice('지도에 표시할 위도·경도 정보가 등록된 매장이 없습니다.');
    }

    final center = NLatLng(
      locatedStores.first.latitude!,
      locatedStores.first.longitude!,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 250,
        child: NaverMap(
          // 지도는 세로 ListView 안에 있으므로 제스처 우선권을 지도에 줘야
          // 드래그/핀치 입력이 부모 스크롤에 가로채이지 않는다.
          forceGesture: true,
          options: NaverMapViewOptions(
            scrollGesturesEnable: true,
            zoomGesturesEnable: true,
            rotationGesturesEnable: true,
            tiltGesturesEnable: true,
            initialCameraPosition: NCameraPosition(
              target: center,
              zoom: locatedStores.length == 1 ? 14 : 7,
            ),
          ),
          onMapReady: (controller) async {
            await controller.addOverlayAll({
              for (final store in locatedStores)
                NMarker(
                  id: 'pickup-store-${store.id}',
                  position: NLatLng(store.latitude!, store.longitude!),
                  caption: NOverlayCaption(text: store.name),
                )..setOnTapListener(
                  (_) => _selectStore(store, revealInList: true),
                ),
            });
          },
        ),
      ),
    );
  }

  /// 설정·좌표 누락 시 빈 지도를 띄우지 않고 원인을 안내한다.
  Widget _mapNotice(String message) => Container(
    width: double.infinity,
    height: 150,
    alignment: Alignment.center,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F1EE),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Color(0xFF6E675F), height: 1.5),
    ),
  );
}
