import '../identity/chat_identity.dart';
import '../models/chat_message.dart';
import '../storage/chat_storage.dart';

class ChatRepository {
  const ChatRepository({
    required this.storage,
    required this.walletAdapter,
  });

  final ChatStorage storage;
  final KTalkWalletAdapter walletAdapter;

  Future<void> saveConversation(Map<String, dynamic> conversation) =>
      storage.saveConversation(conversation);

  List<Map<String, dynamic>> getConversations() => storage.getConversations();

  Future<void> saveMessage(ChatMessage message) => storage.saveMessage(message);

  List<ChatMessage> getMessages(String sender, String receiver) =>
      storage.getMessages(sender, receiver);

  bool hasMessage(String messageId) {
    final keys = storage.getAllMessageKeys();
    for (final key in keys) {
      final messages = storage.getMessagesForKey(key);
      if (messages.any((message) => message.id == messageId)) {
        return true;
      }
    }
    return false;
  }

  bool hasTransactionId(String transactionId) => storage.hasTransactionId(transactionId);

  Future<void> saveContact(Map<String, dynamic> contact) => storage.saveContact(contact);

  List<Map<String, dynamic>> getContacts() => storage.getContacts();

  Future<void> saveHandshakeState(Map<String, dynamic> state) =>
      storage.saveHandshakeState(state);

  List<Map<String, dynamic>> getHandshakeState() => storage.getHandshakeState();

  ChatIdentity get currentIdentity => ChatIdentity.fromWalletAdapter(walletAdapter);
}
