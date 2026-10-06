import 'dart:async';

import 'package:bootcamp_teamproject_1/order/cartController.dart';
import 'package:bootcamp_teamproject_1/user/authController.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 최상위 탭 화면에서 공통으로 유지하는 하단 내비게이션.
class FitpickTabBar extends StatefulWidget {
  const FitpickTabBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  State<FitpickTabBar> createState() => _FitpickTabBarState();
}

class _FitpickTabBarState extends State<FitpickTabBar> {
  bool _switching = false;
  Timer? _switchGuard;
  late final CartController _cart;
  late final AuthController _auth;
  late final List<Worker> _badgeWorkers;
  int _cartCount = 0;
  bool _loggedIn = false;
  static const _items = <(IconData, IconData, String)>[
    (Icons.home_outlined, Icons.home_rounded, '홈'),
    (Icons.grid_view_outlined, Icons.grid_view_rounded, '카테고리'),
    (Icons.shopping_bag_outlined, Icons.shopping_bag_rounded, '장바구니'),
    (Icons.receipt_long_outlined, Icons.receipt_long_rounded, '주문내역'),
    (Icons.person_outline_rounded, Icons.person_rounded, '마이'),
  ];

  @override
  void initState() {
    super.initState();
    // GetX Obx 대신 컨트롤러 변경 리스너로 배지를 갱신해 탭 라우팅과 반응형 빌드를 분리한다.
    _cart = CartController.to;
    _auth = AuthController.to;
    _cartCount = _cart.isLoading.value || _cart.errorMessage.value != null
        ? 0
        : _cart.items.length;
    _loggedIn = _auth.isLoggedIn.value;
    _badgeWorkers = [
      ever(_cart.items, (_) => _syncBadge()),
      ever(_cart.isLoading, (_) => _syncBadge()),
      ever(_cart.errorMessage, (_) => _syncBadge()),
      ever(_auth.isLoggedIn, (_) => _syncBadge()),
    ];
  }

  @override
  void dispose() {
    _switchGuard?.cancel();
    for (final worker in _badgeWorkers) {
      worker.dispose();
    }
    super.dispose();
  }

  void _syncBadge() {
    if (!mounted) return;
    final nextCount = _cart.isLoading.value || _cart.errorMessage.value != null
        ? 0
        : _cart.items.length;
    final nextLoggedIn = _auth.isLoggedIn.value;
    if (_cartCount == nextCount && _loggedIn == nextLoggedIn) return;
    setState(() {
      _cartCount = nextCount;
      _loggedIn = nextLoggedIn;
    });
  }

  void _selectTab(int index) {
    // 현재 탭 선택·빠른 연속 탭으로 GetX 라우트 전환이 중복 실행되지 않게 한다.
    if (_switching || index == widget.selectedIndex) return;
    _switching = true;
    _switchGuard = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _switching = false;
    });
    try {
      widget.onSelected(index);
    } catch (_) {
      _switchGuard?.cancel();
      _switching = false;
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: widget.selectedIndex,
    onDestinationSelected: _selectTab,
    height: 66,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    destinations: [
      for (var i = 0; i < _items.length; i++)
        NavigationDestination(
          icon: i == 2 ? _cartIcon(_items[i].$1) : Icon(_items[i].$1),
          selectedIcon: i == 2 ? _cartIcon(_items[i].$2) : Icon(_items[i].$2),
          label: _items[i].$3,
        ),
    ],
  );

  Widget _cartIcon(IconData icon) => Badge(
    isLabelVisible: _loggedIn && _cartCount > 0,
    label: Text('$_cartCount'),
    child: Icon(icon),
  );
}
