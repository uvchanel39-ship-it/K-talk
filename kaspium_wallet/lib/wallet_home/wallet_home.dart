import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../app_providers.dart';
import '../kaspa/kaspa.dart';
import '../l10n/l10n.dart';
import '../main_card/main_card.dart';
import '../push/push_tap_handler.dart';
import '../transactions/transactions_widget.dart';
import '../transactions/tx_filter_dialog.dart';
import '../util/ui_util.dart';
import '../utxos/utxos_widget.dart';
import '../widgets/gradient_widgets.dart';
import 'wallet_action_buttons.dart';

final _walletWatcherProvider = Provider.autoDispose((ref) {
  ref.watch(virtualDaaScoreProvider);
  ref.watch(virtualSelectedParentBlueScoreStreamProvider);

  ref.watch(addressNotifierProvider);
  ref.watch(balanceNotifierProvider);
  ref.watch(txNotifierProvider);
  ref.watch(utxoNotifierProvider);
  ref.watch(utxoListProvider);
  ref.watch(pendingTxsProvider);
  ref.watch(rpcFeeEstimateProvider);

  ref.watch(addressMonitorProvider);
  ref.watch(pushSyncProvider);
  ref.watch(txMonitorProvider);
});

class WalletHome extends HookConsumerWidget {
  const WalletHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final styles = ref.watch(stylesProvider);
    final l10n = l10nOf(context);

    ref.watch(_walletWatcherProvider);

    useEffect(() {
      final notifier = ref.read(appLinkProvider.notifier);
      return notifier.addListener((appLink) {
        if (appLink == null) {
          return;
        }
        final walletAuth = ref.read(walletAuthNotifierProvider);
        if (walletAuth == null || walletAuth.walletIsLocked) {
          return;
        }
        final prefix = ref.read(addressPrefixProvider);
        final uri = KaspaUri.tryParse(appLink, prefix: prefix);

        Future.microtask(() {
          if (uri == null) {
            UIUtil.showSnackbar(l10n.kaspaUriInvalid);
            return;
          }

          notifier.state = null;

          if (!context.mounted) return;
          UIUtil.showSendFlow(context, ref: ref, uri: uri);
        });
      }, fireImmediately: true);
    }, const []);

    ref.listen(notificationTapProvider, (_, tap) {
      if (tap != null) handlePendingNotificationTap(context, ref);
    });

    ref.listen(walletAuthProvider.select((walletAuth) => walletAuth.isLocked), (
      _,
      isLocked,
    ) {
      if (!isLocked) handlePendingNotificationTap(context, ref);
    });

    useEffect(() {
      Future.microtask(() {
        if (context.mounted) handlePendingNotificationTap(context, ref);
      });
      return null;
    }, const []);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;

    return ColoredBox(
      color: backgroundColor,
      child: Column(
        children: [
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const MainCard(),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 18),
                    height: 52,
                    child: TabBar(
                      indicatorWeight: 3,
                      indicatorColor: const Color(0xff18d8d0),
                      indicatorPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      labelColor: const Color(0xfff3f6ff),
                      unselectedLabelColor: const Color(0xff9aa8c7),
                      labelStyle: styles.textStyleTabLabel.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      unselectedLabelStyle: styles.textStyleTabLabel.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      tabs: [
                        Tab(
                          child: GestureDetector(
                            onLongPress: () => showTxFilterDialog(context, ref),
                            child: Text(l10n.transactionsUppercase),
                          ),
                        ),
                        Tab(child: Text(l10n.utxosUppercase)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        Stack(
                          children: [
                            const TransactionsWidget(),
                            const TopGradientWidget(),
                          ],
                        ),
                        Stack(
                          children: [
                            const UtxosWidget(),
                            const TopGradientWidget(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const WalletActionButtons(),
        ],
      ),
    );
  }
}
