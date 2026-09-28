import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaspium_wallet/kns/kns_inscription_script.dart';
import 'package:kaspium_wallet/kaspa/kaspa.dart';

void main() {
  group('KNS inscription payload', () {
    test('serializes the profile operation in KNS field order', () {
      final payload = KnsInscriptionScript.buildProfilePayload(
        assetId: 'asset-id',
        fieldKey: 'avatarUrl',
        value: 'https://example.test/avatar.png',
      );

      expect(
        String.fromCharCodes(payload),
        '{"op":"addProfile","id":"asset-id","key":"avatarUrl","value":"https://example.test/avatar.png"}',
      );
    });

    test('builds the expected redeem script and P2SH address', () {
      final publicKey = Uint8List.fromList(List.filled(32, 0x11));
      final payload = Uint8List.fromList([0x7b, 0x7d]);
      final expectedScript = Uint8List.fromList([
        0x20,
        ...publicKey,
        0xac,
        0x00,
        0x63,
        0x03,
        0x6b,
        0x6e,
        0x73,
        0x00,
        0x02,
        0x7b,
        0x7d,
        0x68,
      ]);

      final script = KnsInscriptionScript.buildRedeemScript(
        publicKey,
        'kns',
        payload,
      );
      final address = KnsInscriptionScript.commitAddress(
        prefix: AddressPrefix.kaspa,
        redeemScript: expectedScript,
      );

      expect(script, orderedEquals(expectedScript));
      expect(address, isA<Address>());
      expect(address.scriptAddress(), blake2bDigest(data: expectedScript));
      expect(address.prefix, AddressPrefix.kaspa);
    });

    test('uses canonical push-data opcodes at the 75-byte boundary', () {
      expect(KnsInscriptionScript.canonicalPush(Uint8List(75)).first, 75);
      expect(KnsInscriptionScript.canonicalPush(Uint8List(76)).take(2), [
        0x4c,
        76,
      ]);
      expect(KnsInscriptionScript.canonicalPushSize(76), 78);
    });
  });
}
