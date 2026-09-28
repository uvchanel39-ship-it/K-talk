import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../app_icons.dart';
import '../app_providers.dart';
import '../app_router.dart';
import '../contacts/contacts_widget.dart';
import '../kns/kns_contact_avatar.dart';
import '../kns/kns_profile_avatar_button.dart';
import '../l10n/l10n.dart';
import '../settings/available_currency.dart';
import '../settings/available_language.dart';
import '../settings/available_themes.dart';
import '../settings_advanced/advanced_menu.dart';
import '../settings_drawer/contact_support_settings_item.dart';
import '../settings_drawer/currency_dialog.dart';
import '../settings_drawer/language_dialog.dart';
import '../settings_drawer/logout_settings_item.dart';
import '../settings_drawer/network_menu.dart';
import '../settings_drawer/push_settings_item.dart';
import '../settings_drawer/secret_phrase_settings_item.dart';
import '../settings_drawer/security_menu.dart';
import '../settings_drawer/share_settings_item.dart';
import '../settings_drawer/theme_dialog.dart';
import '../util/ui_util.dart';
import '../util/util.dart';
import '../widgets/k_talk_card_decoration.dart';

const _privacyUrl = 'https://kaspium.io/assets/wallet/privacy-policy.html';
const _eulaUrl = 'https://kaspium.io/assets/wallet/eula.html';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final wallet = ref.watch(walletProvider);
    final address = ref.watch(receiveAddressProvider).encoded;
    final currency = ref.watch(currencyProvider);
    final language = ref.watch(languageProvider);
    final themeSetting = ref.watch(themeSettingProvider);
    final pushEnabled = ref.watch(pushEnabledProvider);
    final network = ref.watch(networkProvider).name;
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final pageBackground = isDark ? Colors.black : colorScheme.surface;
    final surface = isDark ? Colors.black : colorScheme.surfaceContainerLow;
    final secondaryText = colorScheme.onSurfaceVariant;
    final walletLocked = ref.watch(walletAuthProvider).isLocked;
    final l10n = l10nOf(context);

    Future<void> copyAddress() async {
      try {
        await Clipboard.setData(ClipboardData(text: address));
        UIUtil.showSnackbar(l10n.addressCopied);
      } catch (_) {
        UIUtil.showSnackbar(l10n.addressCopiedFailed);
      }
    }

    Future<void> showCurrency() async {
      final selection = await showDialog<AvailableCurrencies>(
        context: context,
        builder: (_) => const CurrencyDialog(),
      );
      if (selection != null && context.mounted) {
        ref
            .read(currencyProvider.notifier)
            .updateCurrency(AvailableCurrency(selection));
      }
    }

    Future<void> showLanguage() async {
      final selection = await showDialog<AvailableLanguage>(
        context: context,
        builder: (_) => const LanguageDialog(),
      );
      if (selection != null && context.mounted) {
        ref
            .read(languageProvider.notifier)
            .updateLanguage(LanguageSetting(selection));
      }
    }

    Future<void> showTheme() async {
      final selection = await showDialog<ThemeOptions>(
        context: context,
        builder: (_) => const ThemeDialog(),
      );
      if (selection != null && context.mounted) {
        ref
            .read(themeSettingProvider.notifier)
            .updateTheme(ThemeSetting(selection));
      }
    }

    Future<void> showExisting(Widget child) => showDialog(
      context: context,
      builder: (_) => Dialog.fullscreen(child: child),
    );

    void showContacts() => showExisting(
      ContactsWidget(onBackAction: () => appRouter.pop(context)),
    );
    void showSecurity() =>
        showExisting(SecurityMenu(onBackAction: () => appRouter.pop(context)));
    void showNetwork() =>
        showExisting(NetworkMenu(onBackAction: () => appRouter.pop(context)));
    void showAdvanced() =>
        showExisting(AdvancedMenu(onBackAction: () => appRouter.pop(context)));

    return ColoredBox(
      color: pageBackground,
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
          _ProfileCard(
            name: wallet.name,
            address: address,
            network: network,
            onCopy: copyAddress,
          ),
          const SizedBox(height: 10),
          _AccountInfo(
            status: walletLocked ? 'Terkunci' : 'Online',
            statusColor: walletLocked
                ? colorScheme.error
                : colorScheme.secondary,
            secondaryText: secondaryText,
          ),
          const SizedBox(height: 20),
          const _SectionTitle(title: 'Preferensi'),
          _GroupedCard(
            surface: surface,
            children: [
              _PreferenceItem(
                icon: AppIcons.currency,
                title: l10nOf(context).currency,
                subtitle: currency.getDisplayName(context),
                onTap: showCurrency,
              ),
              _PreferenceItem(
                icon: Icons.translate,
                title: l10nOf(context).language,
                subtitle: language.getDisplayName(context),
                onTap: showLanguage,
              ),
              if (ref.watch(pushAvailableProvider))
                _PreferenceItem(
                  icon: AppIcons.notifications,
                  title: l10nOf(context).notifications,
                  subtitle: pushEnabled
                      ? l10nOf(context).on
                      : l10nOf(context).off,
                  onTap: () => showExisting(const PushSettingsItem()),
                ),
              _PreferenceItem(
                icon: AppIcons.theme,
                title: l10nOf(context).themeHeader,
                subtitle: themeSetting.getDisplayName(context),
                onTap: showTheme,
              ),
              _PreferenceItem(
                icon: AppIcons.security,
                title: l10nOf(context).securityHeader,
                onTap: showSecurity,
              ),
              _PreferenceItem(
                icon: Icons.language,
                title: l10nOf(context).networkHeader,
                subtitle: network,
                onTap: showNetwork,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _SectionTitle(title: 'Kelola'),
          _GroupedCard(
            surface: surface,
            children: [
              _PreferenceItem(
                icon: AppIcons.contact,
                title: l10nOf(context).contactsHeader,
                onTap: showContacts,
              ),
              _PreferenceItem(
                icon: Icons.chat_bubble_outline,
                title: 'K-talk',
                onTap: () => appRouter.openChatHome(context),
              ),
              _PreferenceItem(
                icon: Icons.settings_applications,
                title: l10nOf(context).advancedHeader,
                onTap: showAdvanced,
              ),
              _PreferenceItem(
                icon: AppIcons.backupseed,
                title: l10nOf(context).backupSecretPhrase,
                onTap: () => showExisting(const SecretPhraseSettingsItem()),
              ),
              _PreferenceItem(
                icon: Icons.email_outlined,
                title: l10nOf(context).contactSupport,
                onTap: () => showExisting(const ContactSupportSettingsItem()),
              ),
              _PreferenceItem(
                icon: AppIcons.share,
                title: l10nOf(context).shareKaspium,
                onTap: () => showExisting(const ShareSettingsItem()),
              ),
              _PreferenceItem(
                icon: AppIcons.logout,
                title: l10nOf(context).logoutOrSwitchWallet,
                onTap: () => showExisting(const LogoutSettingsItem()),
              ),
            ],
          ),
          const SizedBox(height: 18),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) => Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      Text('v${snapshot.data?.version ?? ''}'),
                      const Text(' | '),
                      InkWell(
                        onTap: () => openUrl(_privacyUrl),
                        child: Text(
                          l10nOf(context).privacyPolicy,
                          style: const TextStyle(
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const Text(' | '),
                      InkWell(
                        onTap: () => openUrl(_eulaUrl),
                        child: const Text(
                          'EULA',
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            child: IconButton(
              tooltip: 'Kembali ke Chat',
              onPressed: () => appRouter.openChatHome(context),
              icon: const Icon(Icons.arrow_back),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String name;
  final String address;
  final String network;
  final VoidCallback onCopy;

  const _ProfileCard({
    required this.name,
    required this.address,
    required this.network,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final shortAddress = address.length > 22
        ? '${address.substring(0, 12)}...${address.substring(address.length - 7)}'
        : address;
    return Container(
      constraints: const BoxConstraints(minHeight: 150, maxHeight: 165),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: kTalkCardDecoration(context),
      child: Column(
        children: [
          Row(
            children: [
              KnsContactAvatar(address: address, size: 56, fallbackText: name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            shortAddress,
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Salin alamat',
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: onCopy,
                          icon: Icon(
                            Icons.copy_outlined,
                            size: 20,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              KnsProfileAvatarButton(address: address),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: colorScheme.primary.withAlpha(22),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8, color: colorScheme.secondary),
                  const SizedBox(width: 6),
                  Text(
                    network,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountInfo extends StatelessWidget {
  final String status;
  final Color statusColor;
  final Color secondaryText;

  const _AccountInfo({
    required this.status,
    required this.statusColor,
    required this.secondaryText,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withAlpha(38)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AccountStat(
              label: 'Bergabung',
              value: 'Tidak tersedia',
              color: secondaryText,
            ),
          ),
          Container(
            width: 1,
            height: 34,
            color: colorScheme.outline.withAlpha(45),
          ),
          Expanded(
            child: _AccountStat(
              label: 'Status',
              value: status,
              color: statusColor,
              showDot: !status.contains('Terkunci'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool showDot;

  const _AccountStat({
    required this.label,
    required this.value,
    required this.color,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
      ),
      const SizedBox(height: 2),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Icon(Icons.circle, size: 8, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ],
  );
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    child: Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    ),
  );
}

class _GroupedCard extends StatelessWidget {
  final Color surface;
  final List<Widget> children;

  const _GroupedCard({required this.surface, required this.children});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: Container(
      color: surface,
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1)
              Divider(
                height: 1,
                indent: 58,
                color: Theme.of(context).colorScheme.outline.withAlpha(38),
              ),
          ],
        ],
      ),
    ),
  );
}

class _PreferenceItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _PreferenceItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      minVerticalPadding: 8,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, size: 24, color: colorScheme.primary),
      title: Text(
        title,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
      trailing: Icon(
        Icons.chevron_right,
        size: 20,
        color: colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}
