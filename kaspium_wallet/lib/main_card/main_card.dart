import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_icons.dart';
import '../app_providers.dart';
import '../kaspa/types.dart';
import '../l10n/l10n.dart';
import '../util/ui_util.dart';
import '../util/user_data_util.dart';
import '../widgets/app_icon_button.dart';
import '../widgets/k_talk_card_decoration.dart';

final homePageScaffoldKeyProvider = Provider(
  (ref) => GlobalKey<ScaffoldState>(),
);

class MainCard extends ConsumerWidget {
  const MainCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final styles = ref.watch(stylesProvider);
    final l10n = l10nOf(context);

    final wallet = ref.watch(walletProvider);
    final kaspaBalance = ref.watch(formatedTotalBalanceProvider);
    final fiatBalance = ref.watch(formatedTotalFiatProvider);
    final kaspaPrice = ref.watch(formatedKaspaPriceProvider);
    final scaffoldKey = ref.watch(homePageScaffoldKeyProvider);

    Future<void> scanQrCode() async {
      final qrCode = await UserDataUtil.scanQrCode(context);
      final data = qrCode?.code;
      if (data == null) {
        return;
      }

      final prefix = ref.read(addressPrefixProvider);
      final uri = KaspaUri.tryParse(data, prefix: prefix);

      if (uri == null) {
        UIUtil.showSnackbar(l10n.scanQrCodeError);
        return;
      }

      if (!context.mounted) return;
      UIUtil.showSendFlow(context, ref: ref, uri: uri);
    }

    return GestureDetector(
      onTap: () {
        final notifier = ref.read(mainCardProvider.notifier);
        notifier.setNextState();
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 18, 24, 10),
        constraints: const BoxConstraints(minHeight: 132, maxHeight: 148),
        decoration: kTalkCardDecoration(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Consumer(
                    builder: (context, ref, _) {
                      final error = ref.watch(networkErrorProvider);
                      return AppIconButton(
                        icon: error ? AppIcons.warning : AppIcons.settings,
                        size: const Size(28, 28),
                        onPressed: () => scaffoldKey.currentState?.openDrawer(),
                      );
                    },
                  ),
                  const Spacer(),
                  if (wallet.isViewOnly)
                    const SizedBox(width: 28, height: 28)
                  else
                    AppIconButton(
                      icon: Icons.qr_code_2_rounded,
                      size: const Size(28, 28),
                      onPressed: scanQrCode,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/kas_icon.png',
                      width: 56,
                      height: 56,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'KAS',
                            style: TextStyle(
                              color: Color(0xfff5f7ff),
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              kaspaBalance,
                              style: const TextStyle(
                                color: Color(0xfff5f7ff),
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            kaspaPrice,
                            style: const TextStyle(
                              color: Color(0xff18d8d0),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (fiatBalance.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          fiatBalance,
                          textAlign: TextAlign.end,
                          style: styles.textStyleAccount.copyWith(
                            color: const Color(0xffaab7d6),
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
