import 'package:flutter/material.dart';
import 'dart:async';

class KTalkBottomNavigationController extends ChangeNotifier {
  KTalkBottomNavigationController() {
    _restartTimer();
  }

  Timer? _hideTimer;
  bool _visible = true;

  bool get visible => _visible;

  void showAndReset() {
    if (!_visible) {
      _visible = true;
      notifyListeners();
    }
    _restartTimer();
  }

  void _restartTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (!_visible) return;
      _visible = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }
}

class KTalkBottomNavigation extends StatelessWidget {
  final KTalkBottomNavigationController controller;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const KTalkBottomNavigation({
    super.key,
    required this.controller,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) => AnimatedSlide(
        offset: controller.visible ? Offset.zero : const Offset(0, 1),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: IgnorePointer(
          ignoring: !controller.visible,
          child: child,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            selectedItemColor: colorScheme.primary,
            unselectedItemColor: colorScheme.onSurfaceVariant,
            selectedLabelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            showUnselectedLabels: true,
            showSelectedLabels: true,
            elevation: 0,
            onTap: onTap,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.chat_bubble_outline, size: 24),
                activeIcon: Icon(Icons.chat_bubble_rounded, size: 24),
                label: 'Chat',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.explore_outlined, size: 24),
                activeIcon: Icon(Icons.explore_rounded, size: 24),
                label: 'Discover',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_wallet_outlined, size: 24),
                activeIcon: Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 24,
                ),
                label: 'Wallet',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline, size: 24),
                activeIcon: Icon(Icons.person_rounded, size: 24),
                label: 'Profil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
