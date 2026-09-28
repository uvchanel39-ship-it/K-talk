import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

class PreparedChatImage {
  const PreparedChatImage({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
}

class ImageMessage {
  static const int maxDimension = 1280;
  static const int defaultTargetBytes = 15000;

  static PreparedChatImage prepareForChatMessage(
    Uint8List source, {
    String fileName = 'photo.jpg',
    int targetBytes = defaultTargetBytes,
  }) {
    final decoded = img.decodeImage(source);
    if (decoded == null) {
      throw const FormatException('Unable to decode image');
    }

    final longest = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    final resized = longest > maxDimension
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height
                ? maxDimension
                : (decoded.width * maxDimension / decoded.height).round(),
            height: decoded.height >= decoded.width
                ? maxDimension
                : (decoded.height * maxDimension / decoded.width).round(),
          )
        : decoded;

    var quality = 95;
    var bytes = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    while (bytes.length > targetBytes && quality > 5) {
      quality = (quality - 10).clamp(5, 95);
      bytes = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    }

    return PreparedChatImage(
      bytes: bytes,
      fileName: fileName,
      mimeType: 'image/jpeg',
    );
  }

  static String encode({
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'image/jpeg',
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
          !mime.startsWith('image/') ||
          content == null ||
          !content.startsWith('data:')) {
        return null;
      }
      return Map<String, dynamic>.from(value);
    } on FormatException {
      return null;
    }
  }
}
