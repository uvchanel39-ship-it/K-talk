import 'dart:convert';
import 'dart:math';

import 'package:convert/convert.dart';

import '../../fee/fee_providers.dart';
import '../../kaspa/kaspa.dart';
import '../crypto/kasia_cipher.dart';
import '../identity/chat_identity.dart';
import '../models/chat_message.dart';
import '../protocol/message_protocol.dart';
import '../repository/chat_repository.dart';
import '../services/chat_handshake_service.dart';
import '../media/image_message.dart';
import '../media/voice_message.dart';

class ChatTransport {
  const ChatTransport({
    required this.walletService,
    required this.apiService,
    required this.walletAddress,
    this.feeRate = kMinFeeRate,
    this.repository,
    this.senderIdentity,
  });

  final WalletService walletService;
  final ApiService apiService;
  final String walletAddress;
  final int feeRate;
  final ChatRepository? repository;
  final ChatIdentity? senderIdentity;

  Future<List<ChatMessage>> receive({
    required String address,
    int limit = 50,
    List<Transaction>? transactions,
    String? privateKeyHex,
    Future<String> Function(String address)? privateKeyResolver,
    ChatRepository? chatRepository,
  }) async {
    final repo = chatRepository ?? repository;
    final txs =
        transactions ??
        await apiService.getTxsForAddress(
          address,
          pageSize: limit,
          maxPages: 1,
          shouldLoadMore: (_) => false,
        );

    final messages = <ChatMessage>[];
    for (final tx in txs) {
      if (tx.transactionId.isEmpty) {
        continue;
      }

      if (repo != null && repo.hasTransactionId(tx.transactionId)) {
        continue;
      }

      final payload = _extractPayload(tx.payload);
      if (payload == null) {
        continue;
      }

      final parsed = MessageProtocol.parse(payload);
      if (parsed == null) {
        continue;
      }

      final message = await _decodeIncomingMessage(
        tx: tx,
        address: address,
        payload: payload,
        parsed: parsed,
        privateKeyHex: privateKeyHex,
        privateKeyResolver: privateKeyResolver,
        repository: repo,
      );

      if (message == null) {
        continue;
      }

      if (repo != null) {
        await repo.saveMessage(message);
      }
      messages.add(message);
    }

    return messages;
  }

  Future<ChatMessage> sendMessage(
    Object recipient,
    String plaintext, {
    String? senderAddress,
    ChatIdentity? sender,
    ChatIdentity? recipientIdentity,
    String? recipientPublicKeyHex,
    String? alias,
    ChatRepository? chatRepository,
    String? note,
  }) async {
    final resolvedSenderAddress =
        sender?.kaspaAddress ??
        senderAddress ??
        senderIdentity?.kaspaAddress ??
        walletAddress;
    final resolvedRecipientAddress = switch (recipient) {
      ChatIdentity() => recipient.kaspaAddress,
      KTalkWalletAdapter() => recipient.address,
      _ => recipient.toString(),
    };
    final resolvedRecipientIdentity =
        recipientIdentity ??
        (recipient is ChatIdentity ? recipient : null) ??
        (recipient is KTalkWalletAdapter
            ? ChatIdentity.fromWalletAdapter(recipient)
            : null);

    final sanitizedSenderAddress = _validateAddress(
      resolvedSenderAddress,
      'sender',
    );
    final sanitizedRecipientAddress = _validateAddress(
      resolvedRecipientAddress,
      'recipient',
    );

    final resolvedRecipientPublicKey =
        (recipientPublicKeyHex ??
                resolvedRecipientIdentity?.publicKeyHex ??
                _publicKeyFromAddress(sanitizedRecipientAddress))
            .trim();
    if (resolvedRecipientPublicKey.isEmpty) {
      throw StateError(
        'Recipient public key is required before sending a K-Talk message',
      );
    }

    final encrypted = KasiaCipher.encrypt(
      plaintext,
      resolvedRecipientPublicKey,
    );
    final wirePayload = MessageProtocol.serializeCommPayload(
      alias: alias ?? 'ktalk',
      encrypted: encrypted,
    );

    final txId = await send(
      toAddress: sanitizedRecipientAddress,
      payload: wirePayload,
      note: note ?? 'ktalk-chat',
    );

    final message = ChatMessage(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1 << 20).toRadixString(16)}',
      sender: sanitizedSenderAddress,
      receiver: sanitizedRecipientAddress,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      messageType: ChatMessageType.text,
      encryptedPayload: hex.encode(wirePayload),
      transactionId: txId,
      status: ChatMessageStatus.sent,
      metadata: {
        'alias': alias ?? 'ktalk',
        'encryptedFromPublicKey': resolvedRecipientPublicKey,
      },
    );

    final repositoryToUse = chatRepository ?? repository;
    if (repositoryToUse != null) {
      await repositoryToUse.saveMessage(message);
    }

    return message;
  }

  Future<ChatMessage> sendTextMessage({
    required Object recipient,
    required String plaintext,
    String? senderAddress,
    ChatIdentity? sender,
    ChatIdentity? recipientIdentity,
    String? recipientPublicKeyHex,
    String? alias,
    ChatRepository? chatRepository,
    String? note,
  }) async {
    return sendMessage(
      recipient,
      plaintext,
      senderAddress: senderAddress,
      sender: sender,
      recipientIdentity: recipientIdentity,
      recipientPublicKeyHex: recipientPublicKeyHex,
      alias: alias,
      chatRepository: chatRepository,
      note: note,
    );
  }

  Future<ChatMessage?> ensureHandshake({
    required ChatIdentity recipient,
    required ChatRepository chatRepository,
    String alias = 'ktalk',
  }) async {
    final existing = chatRepository.getHandshakeState().where((state) {
      return state['recipientAddress'] == recipient.kaspaAddress ||
          state['senderAddress'] == recipient.kaspaAddress;
    });
    if (existing.any((state) => state['status'] == 'active')) {
      return null;
    }

    final pending = existing.any((state) => state['status'] == 'pending');
    final handshake = ChatHandshakeService().createHandshake(
      senderAddress: chatRepository.currentIdentity.kaspaAddress,
      recipientAddress: recipient.kaspaAddress,
      recipientPublicKeyHex: recipient.publicKeyHex ??
          _publicKeyFromAddress(recipient.kaspaAddress),
      alias: alias,
        isResponse: pending,
    );
    final txId = await send(
      toAddress: recipient.kaspaAddress,
      payload: handshake.payload,
      amount: Amount.raw(BigInt.from(20000000)),
      note: 'ktalk-handshake',
    );
    await chatRepository.saveHandshakeState({
      'sessionId': txId,
      'transactionId': txId,
      'senderAddress': chatRepository.currentIdentity.kaspaAddress,
      'recipientAddress': recipient.kaspaAddress,
      'status': 'active',
      'isResponse': pending,
      'sentAtMs': DateTime.now().millisecondsSinceEpoch,
    });
    await chatRepository.saveContact({
      'address': recipient.kaspaAddress,
      'publicKeyHex': recipient.publicKeyHex,
      'handshakeComplete': true,
      'conversationStatus': 'active',
    });
    return ChatMessage(
      id: txId,
      sender: chatRepository.currentIdentity.kaspaAddress,
      receiver: recipient.kaspaAddress,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      messageType: ChatMessageType.handshake,
      encryptedPayload: hex.encode(handshake.payload),
      transactionId: txId,
      status: ChatMessageStatus.sent,
      plaintext: '[Request to communicate]',
    );
  }

  Future<ChatMessage> sendImageMessage({
    required Object recipient,
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'image/jpeg',
    String? recipientPublicKeyHex,
    ChatRepository? chatRepository,
  }) => sendMessage(
    recipient,
    ImageMessage.encode(fileName: fileName, bytes: bytes, mimeType: mimeType),
    recipientPublicKeyHex: recipientPublicKeyHex,
    chatRepository: chatRepository,
  );

  Future<ChatMessage> sendVoiceMessage({
    required Object recipient,
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'audio/webm',
    String? recipientPublicKeyHex,
    ChatRepository? chatRepository,
  }) => sendMessage(
    recipient,
    VoiceMessage.encode(fileName: fileName, bytes: bytes, mimeType: mimeType),
    recipientPublicKeyHex: recipientPublicKeyHex,
    chatRepository: chatRepository,
  );

  Future<String> send({
    required String toAddress,
    required Uint8List payload,
    Amount? amount,
    String? note,
  }) async {
    final sender = Address.decodeAddress(walletAddress);
    final recipient = Address.decodeAddress(toAddress);
    final spendableUtxos = (await walletService.rpc.getUtxosByAddresses([
      walletAddress,
    ])).toList();

    if (spendableUtxos.isEmpty) {
      throw StateError(
        'No spendable UTXOs available for chat payload transport',
      );
    }

    final sendTx = walletService.createSendTx(
      toAddress: recipient,
      amount: amount ?? Amount.zero,
      spendableUtxos: spendableUtxos,
      feeRate: feeRate,
      changeAddress: sender,
      payload: payload,
      note: note ?? 'ktalk-chat',
    );

    return walletService.sendTransaction(sendTx.tx);
  }

  Future<List<Uint8List>> receivePayloads({
    required String address,
    int limit = 50,
    List<Transaction>? transactions,
  }) async {
    final txs =
        transactions ??
        await apiService.getTxsForAddress(
          address,
          pageSize: limit,
          maxPages: 1,
          shouldLoadMore: (_) => false,
        );

    final payloads = <Uint8List>[];

    for (final tx in txs) {
      final payload = _extractPayload(tx.payload);
      if (payload != null) {
        payloads.add(payload);
      }
    }

    return payloads;
  }

  static String _validateAddress(String value, String role) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw StateError('Missing $role address for K-Talk transport');
    }

    try {
      Address.decodeAddress(normalized);
      return normalized;
    } on Exception {
      throw FormatException('Invalid $role address: $normalized');
    }
  }

  static String _publicKeyFromAddress(String address) {
    final parsed = Address.decodeAddress(address);
    return hex.encode(parsed.scriptAddress());
  }

  static Uint8List? _extractPayload(String rawPayload) {
    final trimmed = rawPayload.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    try {
      return Uint8List.fromList(hex.decode(trimmed));
    } on FormatException {
      return null;
    }
  }

  Future<ChatMessage?> _decodeIncomingMessage({
    required Transaction tx,
    required String address,
    required Uint8List payload,
    required ParsedMessagePayload parsed,
    String? privateKeyHex,
    Future<String> Function(String address)? privateKeyResolver,
    ChatRepository? repository,
  }) async {
    var resolvedPrivateKey = privateKeyHex;
    if (resolvedPrivateKey == null && privateKeyResolver != null) {
      resolvedPrivateKey = await privateKeyResolver(address);
    }

    if (resolvedPrivateKey == null || resolvedPrivateKey.trim().isEmpty) {
      throw StateError(
        'Missing wallet private key to decrypt incoming K-Talk message',
      );
    }

    final comm = parsed.type == MessageProtocol.commType
        ? MessageProtocol.parseCommPayload(payload)
        : null;

    if (comm != null) {
      final plaintext = KasiaCipher.decrypt(comm.message, resolvedPrivateKey);
      final msgId = tx.transactionId.isEmpty
          ? 'ktalk-${DateTime.now().millisecondsSinceEpoch}'
          : tx.transactionId;
      final message = ChatMessage(
        id: msgId,
        sender: _senderFromTransaction(tx) ?? comm.alias,
        receiver: address,
        timestampMs: tx.blockTime * 1000,
        messageType: ChatMessageType.text,
        encryptedPayload: hex.encode(payload),
        transactionId: tx.transactionId,
        status: ChatMessageStatus.received,
        metadata: {
          'senderAlias': comm.alias,
          'plaintext': plaintext,
          'blockTime': tx.blockTime,
          'isKTalk': true,
        },
        plaintext: plaintext,
      );
      return message;
    }

    final handshake = MessageProtocol.parseHandshakePayload(payload);
    if (handshake != null) {
      final decrypted = KasiaCipher.decrypt(handshake, resolvedPrivateKey);
      final handshakeData = _parseHandshakeJson(decrypted);
      final sender = _senderFromTransaction(tx) ??
          (handshakeData?['senderAddress'] as String?) ??
          'unknown';
      final handshakePayload = ChatHandshakeService().parseHandshake(
        senderAddress: sender,
        recipientAddress: address,
        payload: payload,
      );
      if (repository != null && handshakeData != null) {
        final isResponse = handshakeData['isResponse'] == true;
        await repository.saveHandshakeState({
          'sessionId': tx.transactionId,
          'senderAddress': sender,
          'recipientAddress': address,
          ...handshakeData,
          'status': isResponse ? 'active' : 'pending',
          'transactionId': tx.transactionId,
          'receivedAtMs': DateTime.now().millisecondsSinceEpoch,
        });
        await repository.saveContact({
          'address': sender,
          'publicKeyHex': _publicKeyFromAddress(sender),
          'handshakeComplete': isResponse,
          'conversationStatus': isResponse ? 'active' : 'pending',
        });
      }
      return ChatMessage(
        id: tx.transactionId.isEmpty
            ? 'handshake-${DateTime.now().millisecondsSinceEpoch}'
            : tx.transactionId,
        sender: handshakePayload.senderAddress,
        receiver: handshakePayload.recipientAddress,
        timestampMs: tx.blockTime * 1000,
        messageType: ChatMessageType.handshake,
        encryptedPayload: hex.encode(payload),
        transactionId: tx.transactionId,
        status: ChatMessageStatus.received,
        metadata: {
          'plaintext': decrypted,
          ...?handshakeData,
          'blockTime': tx.blockTime,
          'isHandshake': true,
        },
        plaintext: decrypted,
      );
    }

    return null;
  }

  static String? _senderFromTransaction(Transaction tx) {
    for (final input in tx.inputs) {
      final address = input.previousOutpointAddress?.trim();
      if (address != null && address.isNotEmpty) return address;
    }
    return null;
  }

  static Map<String, dynamic>? _parseHandshakeJson(String plaintext) {
    try {
      final decoded = jsonDecode(plaintext);
      if (decoded is! Map || decoded['type'] != 'handshake') return null;
      return Map<String, dynamic>.from(decoded);
    } on FormatException {
      return null;
    }
  }
}
