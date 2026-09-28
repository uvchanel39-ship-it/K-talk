import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_providers.dart';
import '../l10n/l10n.dart';
import '../receive/receive_sheet.dart';
import '../send_sheet/send_sheet.dart';
import '../widgets/sheet_util.dart';

const _actionButtonSize = 52.0;
const _actionButtonGap = 8.0;
const _actionLabelSize = 14.0;

class WalletActionButtons extends ConsumerWidget {
  const WalletActionButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    final theme = ref.watch(themeProvider);
    final l10n = l10nOf(context);

    void showReceive() {
      Sheets.showAppHeightNineSheet(
        context: context,
        widget: const ReceiveSheet(),
        theme: theme,
      );
    }

    void showSend() {
      Sheets.showAppHeightNineSheet(
        context: context,
        widget: const SendSheet(),
        theme: theme,
      );
    }

    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: 24, bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!wallet.isViewOnly)
              _WalletAction(
                label: l10n.send,
                icon: Icons.send_rounded,
                colors: const [Color(0xff6c4dff), Color(0xff8a5cff)],
                onPressed: showSend,
              ),
            if (!wallet.isViewOnly) const SizedBox(height: _actionButtonGap),
            _WalletAction(
              label: l10n.receive,
              icon: Icons.south_rounded,
              colors: const [Color(0xff16cfc8), Color(0xff20bfcB)],
              onPressed: showReceive,
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onPressed;

  const _WalletAction({
    required this.label,
    required this.icon,
    required this.colors,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: colors),
            boxShadow: [
              BoxShadow(
                color: colors.first.withValues(alpha: 0.28),
                blurRadius: 12,
              ),
            ],
          ),
          child: IconButton(
            tooltip: label,
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white, size: 22),
            constraints: const BoxConstraints.tightFor(
              width: _actionButtonSize,
              height: _actionButtonSize,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xfff5f7ff),
            fontSize: _actionLabelSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
