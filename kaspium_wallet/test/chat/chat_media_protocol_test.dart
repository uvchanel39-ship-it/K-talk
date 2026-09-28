import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaspium_wallet/chat/media/image_message.dart';
import 'package:kaspium_wallet/chat/media/voice_message.dart';
import 'package:kaspium_wallet/chat/protocol/message_protocol.dart';

void main() {
  test('image envelope round-trips as KaChat inline media', () {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final encoded = ImageMessage.encode(
      fileName: 'photo.jpg',
      bytes: bytes,
    );
    final parsed = ImageMessage.parse(encoded);

    expect(parsed, isNotNull);
    expect(parsed!['name'], 'photo.jpg');
    expect(parsed['mimeType'], 'image/jpeg');
    expect((parsed['content'] as String).startsWith('data:image/jpeg;base64,'), isTrue);
  });

  test('voice envelope decodes KaChat data URI bytes', () {
    final bytes = Uint8List.fromList([9, 8, 7]);
    final encoded = VoiceMessage.encode(
      fileName: 'voice.webm',
      bytes: bytes,
    );
    final parsed = VoiceMessage.parse(encoded);

    expect(parsed, isNotNull);
    expect(VoiceMessage.decodeBytes(parsed!), bytes);
  });

  test('broadcast protocol preserves content colons and validates channel', () {
    final payload = MessageProtocol.serializeBroadcastPayload(
      channel: ' KaspaNews ',
      content: 'hello:world',
    );
    final parsed = MessageProtocol.parseBroadcastPayload(payload);

    expect(parsed, isNotNull);
    expect(parsed!.channel, 'kaspanews');
    expect(parsed.content, 'hello:world');
  });
}
