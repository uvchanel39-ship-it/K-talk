import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_router.dart';
import '../../app_styles.dart';
import '../../contacts/contact_add_sheet.dart';
import '../../contacts/contacts_providers.dart';
import '../../discovery/discovery_utils.dart';
import '../../kns/kns_contact_avatar.dart';
import '../../screens/profile_screen.dart';
import '../../widgets/k_talk_bottom_navigation.dart';
import '../chat_providers.dart';
import '../models/chat_message.dart';
import '../repository/chat_repository.dart';

class ChatHomeScreen extends ConsumerStatefulWidget {
  final int initialIndex;

  const ChatHomeScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<ChatHomeScreen> createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends ConsumerState<ChatHomeScreen> {
  late int _selectedIndex = widget.initialIndex.clamp(0, 3);
  final _navigationController = KTalkBottomNavigationController();
  final TextEditingController _discoverSearchController =
      TextEditingController();
  DiscoverySort _discoverySort = DiscoverySort.alphabetical;

  @override
  void dispose() {
    _discoverSearchController.dispose();
    _navigationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(chatSyncProvider);
    ref.watch(chatRevisionProvider);
    final repositoryAsync = ref.watch(chatRepositoryProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final secondarySurface = isDark
        ? colorScheme.surface
        : const Color(0xFFF4F5F7);
    final secondaryText = isDark ? Colors.white70 : Colors.black54;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _navigationController.showAndReset(),
      child: Scaffold(
        backgroundColor: backgroundColor,
        extendBody: true,
        floatingActionButton: _selectedIndex == 0
            ? FloatingActionButton(
                onPressed: () => _showNewChatDialog(context, ref),
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                child: const Icon(Icons.add),
              )
            : null,
        body: repositoryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('K-talk is unavailable: $error'),
            ),
          ),
          data: (repository) => SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _buildChatTab(
                  context,
                  repository,
                  ref,
                  isDark,
                  secondarySurface,
                  secondaryText,
                ),
                _buildDiscoveryTab(context, repository, ref, isDark),
                _buildPlaceholderPage(
                  icon: Icons.wallet_outlined,
                  title: 'Wallet',
                  subtitle: 'Managed by the wallet flow.',
                  isDark: isDark,
                ),
                const ProfileScreen(),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _selectedIndex == 3
            ? null
            : KTalkBottomNavigation(
                controller: _navigationController,
                currentIndex: _selectedIndex,
                onTap: (index) {
                  if (index == 2) {
                    setState(() => _selectedIndex = index);
                    appRouter.openWallet(context);
                    return;
                  }
                  setState(() => _selectedIndex = index);
                },
              ),
      ),
    );
  }

  Widget _buildChatTab(
    BuildContext context,
    ChatRepository repository,
    WidgetRef ref,
    bool isDark,
    Color secondarySurface,
    Color secondaryText,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final conversations = repository.getConversations();
    final backgroundColor = isDark ? Colors.black : Colors.white;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
          child: Row(
            children: [
              Text(
                'K-talk',
                style: TextStyle(
                  fontFamily: kDefaultFontFamily,
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  color: colorScheme.primary,
                ),
              ),
              const Spacer(),
              _headerActionButton(
                icon: Icons.photo_camera_outlined,
                onPressed: () {},
              ),
              const SizedBox(width: 8),
              _headerActionButton(
                icon: Icons.more_vert,
                onPressed: () {},
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: secondarySurface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(
                  Icons.search,
                  color: secondaryText.withAlpha(180),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    enabled: false,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Tanya atau cari',
                      hintStyle: TextStyle(
                        color: secondaryText.withAlpha(180),
                        fontSize: 16,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (conversations.isEmpty)
          Expanded(
            child: Container(
              color: backgroundColor,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No conversations yet',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: secondaryText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () => _showNewChatDialog(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('New Chat'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Expanded(
            child: Container(
              color: backgroundColor,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 88),
                itemCount: conversations.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final conversation = conversations[index];
                  final participantA =
                      conversation['participantA'] as String? ?? '';
                  final participantB =
                      conversation['participantB'] as String? ?? '';
                  final peerAddress =
                      participantA == repository.currentIdentity.kaspaAddress
                      ? participantB
                      : participantA;

                  final messages = _messagesForConversation(
                    repository,
                    peerAddress,
                  );
                  final preview = messages.isEmpty
                      ? 'No messages yet'
                      : messages.last.plaintext.isNotEmpty
                      ? messages.last.plaintext
                      : 'Encrypted K-talk payload';
                  final time = messages.isEmpty
                      ? DateTime.now()
                      : DateTime.fromMillisecondsSinceEpoch(
                          messages.last.timestampMs,
                        );
                  final lastMessage = messages.isNotEmpty
                      ? messages.last
                      : null;
                  final hasUnread =
                      lastMessage != null &&
                      lastMessage.sender !=
                          repository.currentIdentity.kaspaAddress &&
                      lastMessage.status != ChatMessageStatus.failed &&
                      lastMessage.status != ChatMessageStatus.pending;

                  return Material(
                    color: isDark
                        ? colorScheme.surface
                        : const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () =>
                          appRouter.openChatConversation(context, peerAddress),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            KnsContactAvatar(
                              address: peerAddress,
                              size: 54,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: KnsContactName(
                                          address: peerAddress,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black,
                                              ),
                                        ),
                                      ),
                                      Text(
                                        DateFormat('HH:mm').format(time),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: hasUnread
                                                  ? colorScheme.primary
                                                  : Colors.grey.shade500,
                                              fontSize: 12,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      if (lastMessage != null) ...[
                                        Icon(
                                          _statusIcon(lastMessage.status),
                                          size: 14,
                                          color: _statusColor(
                                            lastMessage.status,
                                            colorScheme,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      Expanded(
                                        child: Text(
                                          preview,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: Colors.grey.shade500,
                                                fontSize: 14,
                                              ),
                                        ),
                                      ),
                                      if (hasUnread)
                                        Container(
                                          margin: const EdgeInsets.only(
                                            left: 8,
                                          ),
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: colorScheme.primary,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: const Text(
                                            '1',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDiscoveryTab(
    BuildContext context,
    ChatRepository repository,
    WidgetRef ref,
    bool isDark,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final surfaceColor = isDark
        ? const Color(0x0AFFFFFF)
        : const Color(0xFFF6F7F9);
    final secondaryText = isDark ? Colors.white70 : Colors.black54;
    final primaryText = isDark ? Colors.white : Colors.black;
    final mutedDivider = isDark ? Colors.white12 : Colors.black12;
    final contacts = ref.watch(contactsProvider).contacts;
    final query = _discoverSearchController.text;
    final searchedContacts = filterContactsForDiscovery(contacts, query);
    final lastSeenMap = <String, DateTime>{};
    final visibleContacts = sortContactsForDiscovery(
      searchedContacts,
      _discoverySort,
      lastSeenMap,
    );

    final sortLabel = _discoverySort == DiscoverySort.lastSeen
        ? (lastSeenMap.isEmpty
              ? 'Sorted by last seen time (fallback alphabetical)'
              : 'Sorted by last seen time')
        : 'Sorted alphabetically';

    return Container(
      color: backgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SizedBox(
                height: 48,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Discovery',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        color: primaryText,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: PopupMenuButton<DiscoverySort>(
                        tooltip: 'Sort contacts',
                        icon: const Icon(Icons.sort, size: 22),
                        color: surfaceColor,
                        onSelected: (value) {
                          setState(() => _discoverySort = value);
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: DiscoverySort.lastSeen,
                            child: Text('Last seen'),
                          ),
                          const PopupMenuItem(
                            value: DiscoverySort.alphabetical,
                            child: Text('Alphabetical'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: mutedDivider,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Icon(Icons.search, size: 22, color: secondaryText),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _discoverSearchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Search Contacts',
                          hintStyle: TextStyle(
                            color: secondaryText,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: TextStyle(
                          color: primaryText,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    if (_discoverSearchController.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _discoverSearchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear, size: 18),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  _shortcutItem(
                    context: context,
                    icon: Icons.person_add_alt_1_rounded,
                    label: 'Invite Friends',
                    onTap: () async {
                      final inviteText =
                          'Join me on K-talk: ${repository.currentIdentity.kaspaAddress}';
                      final box = context.findRenderObject() as RenderBox?;
                      await SharePlus.instance.share(
                        ShareParams(
                          text: inviteText,
                          sharePositionOrigin: box == null
                              ? null
                              : box.localToGlobal(Offset.zero) & box.size,
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, color: mutedDivider),
                  _shortcutItem(
                    context: context,
                    icon: Icons.history_rounded,
                    label: 'Recent calls',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No recent calls are available yet.'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  sortLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: primaryText,
                  ),
                ),
              ),
            ),
            Expanded(
              child: visibleContacts.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'No contacts yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: secondaryText,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () => showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => const ContactAddSheet(),
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Contact'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 88),
                      itemCount: visibleContacts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 0),
                      itemBuilder: (context, index) {
                        final contact = visibleContacts[index];
                        final initials = contact.name.trim().isEmpty
                            ? '?'
                            : contact.name.trim()[0].toUpperCase();
                        final subtitle = lastSeenMap[contact.address] != null
                            ? 'Last seen ${DateFormat.Hm().format(lastSeenMap[contact.address]!)}'
                            : 'Saved contact';

                        return InkWell(
                          onTap: () => appRouter.openChatConversation(
                            context,
                            contact.address,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: SizedBox(
                              height: 64,
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary.withAlpha(30),
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      initials,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          contact.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w400,
                                            color: primaryText,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: secondaryText,
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
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderPage({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryText = isDark ? Colors.white70 : Colors.black54;

    return Container(
      color: backgroundColor,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 52,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _shortcutItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withAlpha(24),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerActionButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 24),
        ),
      ),
    );
  }

  IconData _statusIcon(ChatMessageStatus status) {
    switch (status) {
      case ChatMessageStatus.pending:
        return Icons.schedule;
      case ChatMessageStatus.sent:
        return Icons.check;
      case ChatMessageStatus.received:
        return Icons.done_all;
      case ChatMessageStatus.delivered:
        return Icons.done_all;
      case ChatMessageStatus.failed:
        return Icons.error_outline;
    }
  }

  Color _statusColor(ChatMessageStatus status, ColorScheme colorScheme) {
    switch (status) {
      case ChatMessageStatus.pending:
        return Colors.orange.shade400;
      case ChatMessageStatus.sent:
        return Colors.grey.shade500;
      case ChatMessageStatus.received:
      case ChatMessageStatus.delivered:
        return colorScheme.primary;
      case ChatMessageStatus.failed:
        return Colors.red.shade400;
    }
  }

  Future<void> _showNewChatDialog(BuildContext context, WidgetRef ref) async {
    final addressController = TextEditingController();
    final keyController = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Chat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: 'Recipient Kaspa address',
                hintText: 'kaspa:...',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: keyController,
              decoration: const InputDecoration(
                labelText: 'Recipient public key (optional)',
                hintText: 'Hex-encoded secp256k1 public key',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop({
              'address': addressController.text.trim(),
              'publicKey': keyController.text.trim(),
            }),
            child: const Text('Open'),
          ),
        ],
      ),
    );

    if (result == null) return;
    final address = result['address'] ?? '';
    if (address.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recipient address is required.')),
        );
      }
      return;
    }

    if (context.mounted) {
      appRouter.openChatConversation(
        context,
        address,
        recipientPublicKeyHex: result['publicKey'],
      );
    }
  }

  List<ChatMessage> _messagesForConversation(
    ChatRepository repository,
    String peerAddress,
  ) {
    final currentAddress = repository.currentIdentity.kaspaAddress;
    final direct = repository.getMessages(currentAddress, peerAddress);
    if (direct.isNotEmpty) {
      final sorted = [...direct]
        ..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
      return sorted;
    }
    final reverse = repository.getMessages(peerAddress, currentAddress);
    final sorted = [...reverse]
      ..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
    return sorted;
  }
}
