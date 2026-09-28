import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kaspium_wallet/app_providers.dart';
import 'package:kaspium_wallet/app_styles.dart';
import 'package:kaspium_wallet/l10n/l10n.dart';
import 'package:kaspium_wallet/main_card/main_card.dart';
import 'package:kaspium_wallet/themes/kaspium_dark_theme.dart';
import 'package:kaspium_wallet/wallet/wallet_types.dart';

void main() {
  testWidgets('MainCard uses compact wallet sizing and KAS icon asset', (
    WidgetTester tester,
  ) async {
    final wallet = WalletInfo(
      name: 'Demo Wallet',
      wid: 'wallet-demo',
      mainnetPublicKey: 'xpub-demo',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletProvider.overrideWithValue(wallet),
          formatedTotalBalanceProvider.overrideWithValue('12.34 KAS'),
          formatedTotalFiatProvider.overrideWithValue(''),
          formatedKaspaPriceProvider.overrideWithValue('\$0.03 / KAS'),
          themeProvider.overrideWithValue(KaspiumDarkTheme()),
          stylesProvider.overrideWithValue(AppStyles(KaspiumDarkTheme())),
          networkErrorProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Center(
              child: SizedBox(width: 420, height: 500, child: MainCard()),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    final cardContainer = tester
        .widgetList<Container>(find.byType(Container))
        .firstWhere((container) => container.decoration is BoxDecoration);
    final boxDecoration = cardContainer.decoration as BoxDecoration;

    expect(
      cardContainer.margin,
      const EdgeInsets.fromLTRB(24, 18, 24, 10),
    );
    expect(boxDecoration.borderRadius, BorderRadius.circular(20));

    final iconImage = tester
        .widgetList<Image>(find.byType(Image))
        .firstWhere(
          (image) =>
              image.image is AssetImage &&
              (image.image as AssetImage).assetName == 'assets/kas_icon.png',
        );
    expect(iconImage.width, closeTo(56, 8));
    expect(iconImage.height, closeTo(56, 8));
  });
}
