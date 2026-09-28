import 'package:flutter/material.dart';

BoxDecoration kTalkCardDecoration(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return BoxDecoration(
    color: isDark ? colorScheme.surface : null,
    gradient: isDark
        ? null
        : LinearGradient(
            colors: [
              colorScheme.surfaceContainerHigh,
              Color.alphaBlend(
                colorScheme.primary.withAlpha(12),
                colorScheme.surfaceContainer,
              ),
            ],
          ),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: isDark
          ? colorScheme.onSurface.withAlpha(25)
          : colorScheme.outline.withAlpha(55),
    ),
    boxShadow: isDark
        ? const []
        : [
            BoxShadow(color: colorScheme.shadow.withAlpha(18), blurRadius: 5),
          ],
  );
}
