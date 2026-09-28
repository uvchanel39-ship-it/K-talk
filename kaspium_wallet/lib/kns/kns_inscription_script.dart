import 'dart:convert';
import 'dart:typed_data';

import '../kaspa/kaspa.dart';

class KnsInscriptionScript {
  static Uint8List buildProfilePayload({
    required String assetId,
    required String fieldKey,
    required String value,
  }) {
    final payload = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'op': 'addProfile',
          'id': assetId.trim(),
          'key': fieldKey,
          'value': value.trim(),
        }),
      ),
    );
    if (payload.length > 520) {
      throw const FormatException('KNS profile payload exceeds 520 bytes');
    }
    return payload;
  }

  static Uint8List buildRedeemScript(
    Uint8List xOnlyPublicKey,
    String title,
    Uint8List payload,
  ) {
    if (xOnlyPublicKey.length != 32) {
      throw const FormatException('KNS requires a 32-byte x-only public key');
    }
    if (title.isEmpty) {
      throw const FormatException('KNS inscription title is empty');
    }
    if (payload.length > 520) {
      throw const FormatException('KNS inscription payload exceeds 520 bytes');
    }
    final titleBytes = Uint8List.fromList(utf8.encode(title));
    final builder = BytesBuilder()
      ..add([0x20])
      ..add(xOnlyPublicKey)
      ..add([0xac, 0x00, 0x63])
      ..add(canonicalPush(titleBytes))
      ..add([0x00])
      ..add(canonicalPush(payload))
      ..add([0x68]);
    return builder.takeBytes();
  }

  static Address commitAddress({
    required AddressPrefix prefix,
    required Uint8List redeemScript,
  }) => Address.scriptHash(
    prefix: prefix,
    hash: blake2bDigest(data: redeemScript),
  );

  static Uint8List canonicalPush(Uint8List data) {
    final length = data.length;
    if (length == 0) return Uint8List.fromList([0]);
    if (length <= 75) return Uint8List.fromList([length, ...data]);
    if (length <= 0xff) return Uint8List.fromList([0x4c, length, ...data]);
    if (length <= 0xffff) {
      return Uint8List.fromList([
        0x4d,
        length & 0xff,
        (length >> 8) & 0xff,
        ...data,
      ]);
    }
    return Uint8List.fromList([
      0x4e,
      length & 0xff,
      (length >> 8) & 0xff,
      (length >> 16) & 0xff,
      (length >> 24) & 0xff,
      ...data,
    ]);
  }

  static int canonicalPushSize(int length) => switch (length) {
    <= 0 => 1,
    <= 75 => length + 1,
    <= 0xff => length + 2,
    <= 0xffff => length + 3,
    _ => length + 5,
  };
}
