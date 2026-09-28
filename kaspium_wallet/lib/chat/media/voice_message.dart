import 'dart:convert';
import 'dart:typed_data';

class VoiceMessage {
  static String encode({
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'audio/webm',
  }) {
    final base64 = base64Encode(bytes);
    return jsonEncode({
      'type': 'file',
      'name': fileName,
      'size': bytes.length,
      'mimeType': mimeType,
      'content': 'data:$mimeType;base64,$base64',
    });
  }

  static Map<String, dynamic>? parse(String text) {
    try {
      final value = jsonDecode(text);
      if (value is! Map || value['type'] != 'file') return null;
      final mime = value['mimeType'] as String?;
      final content = value['content'] as String?;
      if (mime == null ||
          !mime.startsWith('audio/') ||
          content == null ||
          !content.startsWith('data:')) {
        return null;
      }
      return Map<String, dynamic>.from(value);
    } on FormatException {
      return null;
    }
  }

  static Uint8List decodeBytes(Map<String, dynamic> value) {
    final content = value['content'] as String? ?? '';
    final comma = content.indexOf(',');
    if (comma < 0) throw const FormatException('Invalid voice data URI');
    return Uint8List.fromList(base64Decode(content.substring(comma + 1)));
  }
}
