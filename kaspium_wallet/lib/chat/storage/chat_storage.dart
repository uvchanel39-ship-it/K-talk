import 'package:hive/hive.dart';

import '../../database/boxes.dart';
import '../models/chat_message.dart';

class ChatStorage {
  ChatStorage._fromOpenBoxes({
    required this._conversations,
    required this._messages,
    required this._contacts,
    required this._handshakes,
  });

  ChatStorage.withBoxes({
    required Box conversations,
    required Box messages,
    required Box contacts,
    required Box handshakes,
  })  : _conversations = GenericBox(conversations),
        _messages = GenericBox(messages),
        _contacts = GenericBox(contacts),
        _handshakes = GenericBox(handshakes);

  final GenericBox _conversations;
  final GenericBox _messages;
  final GenericBox _contacts;
  final GenericBox _handshakes;

  static ChatStorage? _instance;
  static Future<ChatStorage>? _initializing;

  static Future<ChatStorage> open() async {
    final existing = _instance;
    if (existing != null &&
        [
          existing._conversations.box,
          existing._messages.box,
          existing._contacts.box,
          existing._handshakes.box,
        ].every((box) => box.isOpen)) {
      return existing;
    }

    if (_initializing != null) {
      return _initializing!;
    }

    _instance = null;
    _initializing = _openInternal();

    try {
      final storage = await _initializing!;
      _instance = storage;
      _initializing = null;
      return storage;
    } catch (_) {
      _initializing = null;
      rethrow;
    }
  }

  static Future<ChatStorage> _openInternal() async {
    const conversationBoxKey = '_ktalk_conversations';
    const messageBoxKey = '_ktalk_messages';
    const contactBoxKey = '_ktalk_contacts';
    const handshakeBoxKey = '_ktalk_handshakes';

    final boxKeys = [
      conversationBoxKey,
      messageBoxKey,
      contactBoxKey,
      handshakeBoxKey,
    ];

    await Future.wait(
      boxKeys.map((boxKey) async {
        if (!Hive.isBoxOpen(boxKey)) {
          await Hive.openBox<dynamic>(boxKey);
        }
      }),
    );

    return ChatStorage._fromOpenBoxes(
      conversations: GenericBox(Hive.box<dynamic>(conversationBoxKey)),
      messages: GenericBox(Hive.box<dynamic>(messageBoxKey)),
      contacts: GenericBox(Hive.box<dynamic>(contactBoxKey)),
      handshakes: GenericBox(Hive.box<dynamic>(handshakeBoxKey)),
    );
  }

  Future<void> saveConversation(Map<String, dynamic> conversation) async {
    final targetId = conversation['id'] as String?;
    if (targetId == null || targetId.trim().isEmpty) {
      throw const FormatException('Conversation id is required');
    }

    final items = _readMapList(_conversations, 'all');
    final updated = <Map<String, dynamic>>[];
    var replaced = false;

    for (final item in items) {
      if ((item['id'] as String?) == targetId) {
        updated.add(conversation);
        replaced = true;
      } else {
        updated.add(item);
      }
    }

    if (!replaced) {
      updated.add(conversation);
    }

    await _conversations.setList('all', updated, convert: (item) => item);
  }

  List<Map<String, dynamic>> getConversations() => _readMapList(_conversations, 'all');

  Future<void> saveMessage(ChatMessage message) async {
    final key = 'conversation:${message.sender}::${message.receiver}';
    final items = _readMapList(_messages, key);
    final updated = <Map<String, dynamic>>[];
    var replaced = false;

    for (final item in items) {
      if ((item['id'] as String?) == message.id) {
        updated.add(message.toJson());
        replaced = true;
      } else {
        updated.add(item);
      }
    }

    if (!replaced) {
      updated.add(message.toJson());
    }

    await _messages.setList(key, updated, convert: (item) => item);

    final transactionId = message.transactionId?.trim();
    if (transactionId != null && transactionId.isNotEmpty) {
      final transactionIds = _messages.box.get('_transaction_ids');
      final indexed = transactionIds is List
          ? transactionIds.whereType<String>().toSet()
          : <String>{};
      indexed.add(transactionId);
      await _messages.setList(
        '_transaction_ids',
        indexed.toList(growable: false),
      );
    }

    final conversations = _readMapList(_conversations, 'all');
    final conversationId = '${message.sender}::${message.receiver}';
    final normalized = <Map<String, dynamic>>[];
    var conversationReplaced = false;

    for (final item in conversations) {
      final currentId = (item['id'] as String?) ?? '${item['participantA']}::${item['participantB']}';
      if (currentId == conversationId) {
        normalized.add({
          'id': conversationId,
          'participantA': message.sender,
          'participantB': message.receiver,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        });
        conversationReplaced = true;
      } else {
        normalized.add(item);
      }
    }

    if (!conversationReplaced) {
      normalized.add({
        'id': conversationId,
        'participantA': message.sender,
        'participantB': message.receiver,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });
    }

    await _conversations.setList('all', normalized, convert: (item) => item);
  }

  List<ChatMessage> getMessages(String sender, String receiver) {
    final key = 'conversation:$sender::$receiver';
    final items = _readMapList(_messages, key);
    return items.map((item) => ChatMessage.fromJson(item)).toList(growable: false);
  }

  List<String> getAllMessageKeys() => _messages.box.keys.whereType<String>().toList(growable: false);

  List<ChatMessage> getMessagesForKey(String key) {
    final items = _readMapList(_messages, key);
    return items.map((item) => ChatMessage.fromJson(item)).toList(growable: false);
  }

  bool hasTransactionId(String transactionId) {
    final indexed = _messages.box.get('_transaction_ids');
    if (indexed is List && indexed.contains(transactionId)) return true;

    final keys = _messages.box.keys
      .whereType<String>()
      .where((key) => key != '_transaction_ids');
    for (final key in keys) {
      final items = _readMapList(_messages, key);
      if (items.any((item) => (item['transactionId'] as String?) == transactionId)) {
        return true;
      }
    }
    return false;
  }

  Future<void> saveContact(Map<String, dynamic> contact) async {
    final targetId = contact['address'] as String? ?? contact['id'] as String?;
    if (targetId == null || targetId.trim().isEmpty) {
      throw const FormatException('Contact identifier is required');
    }

    final items = _readMapList(_contacts, 'all');
    final updated = <Map<String, dynamic>>[];
    var replaced = false;

    for (final item in items) {
      final current = item['address'] as String? ?? item['id'] as String?;
      if (current == targetId) {
        updated.add(contact);
        replaced = true;
      } else {
        updated.add(item);
      }
    }

    if (!replaced) {
      updated.add(contact);
    }

    await _contacts.setList('all', updated, convert: (item) => item);
  }

  List<Map<String, dynamic>> getContacts() => _readMapList(_contacts, 'all');

  Future<void> saveHandshakeState(Map<String, dynamic> state) async {
    final key = state['sessionId'] as String? ?? state['id'] as String?;
    if (key == null || key.trim().isEmpty) {
      throw const FormatException('Handshake session id is required');
    }

    final items = _readMapList(_handshakes, 'all');
    final updated = <Map<String, dynamic>>[];
    var replaced = false;

    for (final item in items) {
      final current = item['sessionId'] as String? ?? item['id'] as String?;
      if (current == key) {
        updated.add(state);
        replaced = true;
      } else {
        updated.add(item);
      }
    }

    if (!replaced) {
      updated.add(state);
    }

    await _handshakes.setList('all', updated, convert: (item) => item);
  }

  List<Map<String, dynamic>> getHandshakeState() => _readMapList(_handshakes, 'all');

  Future<void> removeMessage(String messageId) async {
    final keys = _messages.box.keys.whereType<String>();
    for (final key in keys) {
      final items = _readMapList(_messages, key);
      final filtered = items.where((item) => (item['id'] as String?) != messageId).toList();
      if (filtered.length != items.length) {
        await _messages.setList(key, filtered, convert: (item) => item);
      }
    }
  }

  Future<void> clear() async {
    await Future.wait([
      _conversations.clear(),
      _messages.clear(),
      _contacts.clear(),
      _handshakes.clear(),
    ]);
  }

  static List<Map<String, dynamic>> _readMapList(GenericBox box, String key) {
    final list = box.tryGetList<Map<String, dynamic>>(
      key,
      typeFactory: (value) => Map<String, dynamic>.from(value as Map),
    );
    return list ?? const <Map<String, dynamic>>[];
  }
}
