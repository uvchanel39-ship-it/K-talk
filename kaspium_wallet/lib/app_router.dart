import 'package:flutter/material.dart';

import 'chat/ui/chat_conversation_screen.dart';
import 'chat/ui/chat_home_screen.dart';
import 'screens/screens.dart';
import 'util/routes.dart';

final appRouter = AppRouter();

class _AppScreens {
  static const splash = '/';
  static const intro = '/intro';
  static const wallet = '/wallet';
  static const locked = '/locked';
  static const lockedWithTransition = '/locked_with_transition';
  static const passwordLocked = '/password_locked';
  static const logout = '/logout';
  static const setupWallet = '/setup_wallet';
  static const switchWallet = '/switch_wallet';
  static const chatHome = '/chat_home';
  static const chatConversation = '/chat_conversation';
}

class AppRouter {
  void reload(BuildContext context) =>
      _replaceWith(_AppScreens.splash, context);

  void startIntro(BuildContext context) =>
      _replaceWith(_AppScreens.intro, context);

  void setupWallet(BuildContext context) =>
      _replaceWith(_AppScreens.setupWallet, context);

  void requireUnlock(BuildContext context) =>
      _replaceWith(_AppScreens.locked, context);

  void lockoutkWithTransition(BuildContext context) =>
      _replaceWith(_AppScreens.lockedWithTransition, context);

  void requirePassword(BuildContext context) =>
      _replaceWith(_AppScreens.passwordLocked, context);

  void openWallet(BuildContext context) =>
      _replaceWith(_AppScreens.wallet, context);

  void logout(BuildContext context) =>
      _replaceWith(_AppScreens.logout, context);

  void switchWallet(BuildContext context, String walletId) =>
      _replaceWith(_AppScreens.switchWallet, context, arguments: walletId);

  void openChatHome(BuildContext context, {int initialIndex = 0}) => _push(
    _AppScreens.chatHome,
    context,
    arguments: initialIndex,
  );

  void openChatConversation(
    BuildContext context,
    String recipientAddress, {
    String? recipientPublicKeyHex,
  }) => _push(
    _AppScreens.chatConversation,
    context,
    arguments: {
      'recipientAddress': recipientAddress,
      'recipientPublicKeyHex': recipientPublicKeyHex,
    },
  );

  bool isTopRoute<T>(BuildContext context) {
    bool isTopRoute = false;
    Navigator.of(context).popUntil((route) {
      isTopRoute = route is T;
      return true;
    });
    return isTopRoute;
  }

  Future<T?> _replaceWith<T>(
    String screenName,
    BuildContext context, {
    Object? arguments,
  }) {
    return Navigator.of(context).pushNamedAndRemoveUntil(
      screenName,
      (_) => false,
      arguments: arguments,
    );
  }

  Future<T?> _push<T>(
    String screenName,
    BuildContext context, {
    Object? arguments,
  }) {
    return Navigator.of(context).pushNamed(
      screenName,
      arguments: arguments,
    );
  }

  Future<T?> push<T>(BuildContext context, Route<T> route) {
    return Navigator.of(context).push(route);
  }

  void pop<T>(BuildContext context, {T? withResult}) {
    Navigator.of(context).pop(withResult);
  }

  void maybePop<T>(BuildContext context, {T? withResult}) {
    Navigator.of(context).maybePop(withResult);
  }

  Future<T?> pushAndRemoveUntilHome<T>(BuildContext context, Route<T> route) {
    return Navigator.of(context).pushAndRemoveUntil(
      route,
      RouteUtils.withNameLike(_AppScreens.wallet),
    );
  }

  String initialRoute = _AppScreens.splash;

  RouteFactory onGenerateRoute = (RouteSettings settings) {
    switch (settings.name) {
      case _AppScreens.intro:
        return NoTransitionRoute(
          builder: (_) => const IntroScreen(),
          settings: settings,
        );
      case _AppScreens.wallet:
        return NoTransitionRoute(
          builder: (_) => const HomeScreen(),
          settings: settings,
        );
      case _AppScreens.locked:
        return BarrierRoute(
          builder: (_) => const LockScreen(),
          settings: settings,
        );
      case _AppScreens.lockedWithTransition:
        return BarrierRoute(
          builder: (_) => const LockScreen(),
          settings: settings,
        );
      case _AppScreens.passwordLocked:
        return NoTransitionRoute(
          builder: (_) => const PasswordLockScreen(),
          settings: settings,
        );
      case _AppScreens.logout:
        return NoTransitionRoute(
          builder: (_) => const LogoutScreen(),
          settings: settings,
        );
      case _AppScreens.setupWallet:
        return NoTransitionRoute(
          builder: (_) => const SetupWalletScreen(),
          settings: settings,
        );
      case _AppScreens.switchWallet when settings.arguments is String:
        return NoTransitionRoute(
          builder: (_) => SwitchWalletScreen(
            walletId: settings.arguments as String,
          ),
          settings: settings,
        );
      case _AppScreens.chatHome:
        return NoTransitionRoute(
          builder: (_) => ChatHomeScreen(
            initialIndex: settings.arguments is int
                ? settings.arguments as int
                : 0,
          ),
          settings: settings,
        );
      case _AppScreens.chatConversation:
        final args = settings.arguments is Map
            ? settings.arguments as Map
            : const {};
        final recipientAddress = args['recipientAddress'] as String? ?? '';
        final recipientPublicKeyHex = args['recipientPublicKeyHex'] as String?;
        return NoTransitionRoute(
          builder: (_) => ChatConversationScreen(
            recipientAddress: recipientAddress,
            recipientPublicKeyHex: recipientPublicKeyHex,
          ),
          settings: settings,
        );
      default:
        return NoTransitionRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
    }
  };
}
