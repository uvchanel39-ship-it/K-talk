import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../chat_providers.dart';
import '../identity/chat_identity.dart';
import '../models/chat_message.dart';
import '../repository/chat_repository.dart';
import '../../kns/kns_contact_avatar.dart';

class ChatConversationScreen extends ConsumerStatefulWidget {
  const ChatConversationScreen({
    super.key,
    required this.recipientAddress,
    this.recipientPublicKeyHex,
  });

  final String recipientAddress;
  final String? recipientPublicKeyHex;

  @override
  ConsumerState<ChatConversationScreen> createState() =>
      _ChatConversationScreenState();
}

class _ChatConversationScreenState extends ConsumerState<ChatConversationScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(chatSyncProvider);
    ref.watch(chatRevisionProvider);
    final repositoryAsync = ref.watch(chatRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            KnsContactAvatar(
              address: widget.recipientAddress,
              size: 36,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: KnsContactName(
                address: widget.recipientAddress,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
      body: repositoryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Failed to load K-talk conversation: $error'),
        ),
        data: (repository) {
          final currentAddress = repository.currentIdentity.kaspaAddress;
          final messages = _messagesForConversation(repository, currentAddress);

          final list = messages.isEmpty
              ? const Center(
                  child: Text('No messages yet. Start the conversation.'))
              : ListView.builder(
                  reverse: false,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMine = message.sender == currentAddress;
                    final when = DateTime.fromMillisecondsSinceEpoch(
                      message.timestampMs,
                    );

                    return Align(
                      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.78,
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isMine
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.plaintext.isEmpty
                                  ? 'Encrypted payload'
                                  : message.plaintext,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  DateFormat('HH:mm').format(when),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                                if (isMine) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    message.status.name,
                                    style: Theme.of(context).textTheme.labelSmall,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );

          return SafeArea(
            child: Column(
              children: [
                Expanded(child: list),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'Type a message',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () => _sendMessage(repository),
                        icon: const Icon(Icons.send),
                        label: const Text('Send'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _sendMessage(ChatRepository repository) async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }

    try {
      final transport = ref.read(chatTransportProvider);
      await transport.ensureHandshake(
        recipient: ChatIdentity(
          kaspaAddress: widget.recipientAddress,
          network: repository.currentIdentity.network,
          publicKeyHex: widget.recipientPublicKeyHex,
        ),
        chatRepository: repository,
      );
      await transport.sendTextMessage(
        recipient: widget.recipientAddress,
        plaintext: text,
        senderAddress: repository.currentIdentity.kaspaAddress,
        recipientPublicKeyHex: widget.recipientPublicKeyHex,
        chatRepository: repository,
      );
      _controller.clear();
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Send failed: $error')),
        );
      }
    }
  }

  List<ChatMessage> _messagesForConversation(
    ChatRepository repository,
    String currentAddress,
  ) {
    final direct = repository.getMessages(currentAddress, widget.recipientAddress);
    if (direct.isNotEmpty) {
      final sorted = [...direct]..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
      return sorted;
    }

    final reverse = repository.getMessages(widget.recipientAddress, currentAddress);
    final sorted = [...reverse]..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
    return sorted;
  }
}
