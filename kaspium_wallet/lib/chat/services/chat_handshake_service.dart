import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart';

import '../crypto/kasia_cipher.dart';
import '../protocol/message_protocol.dart';

class ChatHandshake {
  const ChatHandshake({
    required this.senderAddress,
    required this.recipientAddress,
    required this.payload,
    required this.createdAtMs,
  });

  final String senderAddress;
  final String recipientAddress;
  final Uint8List payload;
  final int createdAtMs;

  Uint8List get serializedPayload => payload;

  String toHex() => hex.encode(payload);

  static ChatHandshake fromPayload({
    required String senderAddress,
    required String recipientAddress,
    required Uint8List payload,
  }) => ChatHandshake(
        senderAddress: senderAddress,
        recipientAddress: recipientAddress,
        payload: payload,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );
}

class ChatHandshakeService {
  ChatHandshakeService();

  ChatHandshake createHandshake({
    required String senderAddress,
    required String recipientAddress,
    String senderPrivateKeyHex = '',
    required String recipientPublicKeyHex,
    String alias = 'ktalk',
    bool isResponse = false,
    String? theirAlias,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final handshakeJson = jsonEncode({
      'type': 'handshake',
      'alias': _normalizeAlias(alias),
      'timestamp': timestamp,
      'conversationId': null,
      'version': 1,
      'recipientAddress': recipientAddress,
      'sendToRecipient': true,
      'isResponse': isResponse,
      'theirAlias': theirAlias,
    });
    final encrypted = KasiaCipher.encrypt(
      handshakeJson,
      recipientPublicKeyHex,
    );

    final payload = MessageProtocol.serializeHandshakePayload(encrypted);
    return ChatHandshake(
      senderAddress: senderAddress,
      recipientAddress: recipientAddress,
      payload: payload,
      createdAtMs: timestamp,
    );
  }

  bool validateHandshakePayload(Uint8List payload) {
    return MessageProtocol.parseHandshakePayload(payload) != null;
  }

  ChatHandshake parseHandshake({
    required String senderAddress,
    required String recipientAddress,
    required Uint8List payload,
  }) {
    if (!validateHandshakePayload(payload)) {
      throw FormatException('Invalid handshake payload');
    }

    return ChatHandshake(
      senderAddress: senderAddress,
      recipientAddress: recipientAddress,
      payload: payload,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  static String _normalizeAlias(String alias) {
    final normalized = alias.toLowerCase().replaceAll(RegExp(r'[^0-9a-f]'), '');
    if (normalized.length >= 12) return normalized.substring(0, 12);
    return normalized.padLeft(12, '0');
  }
}
