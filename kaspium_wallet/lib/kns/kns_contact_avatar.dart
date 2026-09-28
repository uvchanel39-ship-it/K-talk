import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_providers.dart';
import 'kns_providers.dart';

class KnsContactAvatar extends ConsumerWidget {
  const KnsContactAvatar({
    super.key,
    required this.address,
    required this.size,
    this.fallbackText,
  });

  final String address;
  final double size;
  final String? fallbackText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contact = ref.watch(
      contactsProvider.select(
        (notifier) => notifier.getContactWithAddress(address),
      ),
    );
    final profile = ref.watch(knsProfileProvider(address)).valueOrNull;
    final avatarUrl = contact?.avatarUrl ?? profile?.avatarUrl;
    final imagePath = avatarUrl == null
        ? null
        : ref
              .watch(
                knsAvatarPathProvider((address: address, avatarUrl: avatarUrl)),
              )
              .valueOrNull;

    if (imagePath != null) {
      return ClipOval(
        child: Image.file(
          File(imagePath),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _fallback(context, contact?.name, profile?.domain),
        ),
      );
    }
    return _fallback(context, contact?.name, profile?.domain);
  }

  Widget _fallback(BuildContext context, String? localName, String? domain) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = localName?.trim().isNotEmpty == true
        ? localName!
        : domain?.trim().isNotEmpty == true
        ? domain!
        : (fallbackText?.trim().isNotEmpty == true ? fallbackText! : address);
    final initial = label.isEmpty ? '?' : label.characters.first.toUpperCase();
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: colorScheme.primary.withAlpha(20),
      child: Text(
        initial,
        style: TextStyle(
          color: colorScheme.primary,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class KnsContactName extends ConsumerWidget {
  const KnsContactName({
    super.key,
    required this.address,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  final String address;
  final TextStyle? style;
  final int maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contact = ref.watch(
      contactsProvider.select(
        (notifier) => notifier.getContactWithAddress(address),
      ),
    );
    final profile = ref.watch(knsProfileProvider(address)).valueOrNull;
    final localName = contact?.name.trim();
    final profileName = profile?.domain?.trim();
    final displayName = address.isEmpty
        ? 'Unknown contact'
        : localName?.isNotEmpty == true
        ? localName!
        : profileName?.isNotEmpty == true
        ? profileName!
        : _shortAddress(address);

    return Text(
      displayName,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  String _shortAddress(String value) {
    if (value.length <= 23) return value;
    return '${value.substring(0, 12)}...${value.substring(value.length - 8)}';
  }
}
