import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

final _secp256k1 = ECDomainParameters('secp256k1');
final _secp256k1Prime = BigInt.parse(
  'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F',
  radix: 16,
);

class EncryptedMessage {
  const EncryptedMessage({
    required this.nonce,
    required this.ephemeralPublicKey,
    required this.ciphertext,
  });

  final Uint8List nonce;
  final Uint8List ephemeralPublicKey;
  final Uint8List ciphertext;

  Uint8List toBytes() => Uint8List.fromList([...nonce, ...ephemeralPublicKey, ...ciphertext]);

  factory EncryptedMessage.fromBytes(Uint8List bytes) {
    if (bytes.length < 12 + 32 + 16) {
      throw const FormatException('Ciphertext is too short to contain nonce, ephemeral key and tag');
    }

    final nonce = bytes.sublist(0, 12);
    final firstKeyByte = bytes[12];
    final keyLength = (firstKeyByte == 0x02 || firstKeyByte == 0x03) ? 33 : 32;
    final keyEnd = 12 + keyLength;
    if (bytes.length < keyEnd + 16) {
      throw const FormatException('Ciphertext is missing authentication tag');
    }

    return EncryptedMessage(
      nonce: nonce,
      ephemeralPublicKey: bytes.sublist(12, keyEnd),
      ciphertext: bytes.sublist(keyEnd),
    );
  }

  String toHex() => hex.encode(toBytes());

  factory EncryptedMessage.fromHex(String hexValue) =>
      EncryptedMessage.fromBytes(Uint8List.fromList(hex.decode(hexValue)));

  @override
  String toString() => 'EncryptedMessage(nonce=${hex.encode(nonce)}, ephemeral=${hex.encode(ephemeralPublicKey)})';
}

class KasiaCipher {
  static const int _nonceLength = 12;

  static Uint8List generatePrivateKey() {
    final random = Random.secure();
    while (true) {
      final candidate = Uint8List(32);
      for (var i = 0; i < candidate.length; i++) {
        candidate[i] = random.nextInt(256);
      }
      final value = BigInt.parse(hex.encode(candidate), radix: 16);
      if (value > BigInt.zero && value < _secp256k1.n) {
        return candidate;
      }
    }
  }

  static String generatePrivateKeyHex() => hex.encode(generatePrivateKey());

  static String derivePublicKeyHex(String privateKeyHex) {
    final privateKey = _validatePrivateKeyHex(privateKeyHex);
    final point = (_secp256k1.G * privateKey)!;
    final x = point.x!.toBigInteger()!;
    final y = point.y!.toBigInteger()!;
    return '04${x.toRadixString(16).padLeft(64, '0')}${y.toRadixString(16).padLeft(64, '0')}';
  }

  static Uint8List deriveSharedSecret({
    required String privateKeyHex,
    required String peerPublicKeyHex,
  }) {
    final privateKey = _validatePrivateKeyHex(privateKeyHex);
    final peerPoint = _decodePublicKey(peerPublicKeyHex);
    final sharedPoint = peerPoint * privateKey;
    final x = sharedPoint!.x!.toBigInteger()!;
    return _toFixedLengthBytes(x, 32);
  }

  static EncryptedMessage encrypt(String plaintext, String recipientPublicKeyHex) {
    final recipientPoint = _decodePublicKey(recipientPublicKeyHex);
    final ephemeralPrivate = _validatePrivateKeyHex(generatePrivateKeyHex());
    final ephemeralPoint = (_secp256k1.G * ephemeralPrivate)!;

    final sharedSecret = _ecdhSharedX(ephemeralPrivate, recipientPoint);
    final key = hkdfSha256(sharedSecret, Uint8List(0), Uint8List(0), 32);
    final nonce = _randomBytes(_nonceLength);

    final cipher = ChaCha20Poly1305(ChaCha7539Engine(), Poly1305())
      ..init(
        true,
        AEADParameters(KeyParameter(Uint8List.fromList(key)), 128, nonce, Uint8List(0)),
      );

    final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));
    final output = Uint8List(cipher.getOutputSize(plaintextBytes.length));
    var len = cipher.processBytes(plaintextBytes, 0, plaintextBytes.length, output, 0);
    len += cipher.doFinal(output, len);

    return EncryptedMessage(
      nonce: nonce,
      ephemeralPublicKey: _compressedPublicKeyBytes(ephemeralPoint),
      ciphertext: output.sublist(0, len),
    );
  }

  static String deriveDeterministicAlias({
    required String privateKeyHex,
    required String peerPublicKeyHex,
    required String contextPublicKeyHex,
  }) {
    final privateKey = _validatePrivateKeyHex(privateKeyHex);
    final peerPoint = _decodePublicKey(peerPublicKeyHex);
    final sharedSecret = _ecdhSharedX(privateKey, peerPoint);
    final context = _publicKeyXBytes(contextPublicKeyHex);
    final info = Uint8List.fromList([
      ...utf8.encode('chat'),
      ...sharedSecret,
      ...context,
    ]);
    return hex.encode(hkdfSha256(sharedSecret, Uint8List(0), info, 6));
  }

  static String decrypt(EncryptedMessage encryptedMessage, String privateKeyHex) {
    final privateKey = _validatePrivateKeyHex(privateKeyHex);
    final ephemeralPoint = _decodePublicKey(hex.encode(encryptedMessage.ephemeralPublicKey));
    final sharedSecret = _ecdhSharedX(privateKey, ephemeralPoint);
    final key = hkdfSha256(sharedSecret, Uint8List(0), Uint8List(0), 32);

    final cipher = ChaCha20Poly1305(ChaCha7539Engine(), Poly1305())
      ..init(
        false,
        AEADParameters(KeyParameter(Uint8List.fromList(key)), 128, encryptedMessage.nonce, Uint8List(0)),
      );

    final output = Uint8List(cipher.getOutputSize(encryptedMessage.ciphertext.length));
    var len = cipher.processBytes(encryptedMessage.ciphertext, 0, encryptedMessage.ciphertext.length, output, 0);
    len += cipher.doFinal(output, len);

    return utf8.decode(output.sublist(0, len));
  }

  static Uint8List hkdfSha256(Uint8List ikm, Uint8List salt, Uint8List info, int outLen) {
    final actualSalt = salt.isEmpty ? Uint8List(32) : salt;
    final prk = Hmac(sha256, actualSalt).convert(ikm).bytes;

    final result = BytesBuilder();
    var previous = <int>[];
    var counter = 1;

    while (result.length < outLen) {
      final input = [...previous, ...info, counter];
      previous = Hmac(sha256, prk).convert(input).bytes;
      result.add(previous);
      counter++;
    }

    return result.toBytes().sublist(0, outLen);
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(List<int>.generate(length, (_) => random.nextInt(256)));
  }

  static BigInt _validatePrivateKeyHex(String value) {
    final normalized = value.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (normalized.length != 64) {
      throw FormatException('Private key must be 32 bytes / 64 hex chars: $value');
    }
    final parsed = BigInt.parse(normalized, radix: 16);
    if (parsed <= BigInt.zero || parsed >= _secp256k1.n) {
      throw FormatException('Private key not in valid secp256k1 range');
    }
    return parsed;
  }

  static ECPoint _decodePublicKey(String publicKeyHex) {
    final normalized = publicKeyHex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (normalized.length == 64) {
      final x = BigInt.parse(normalized, radix: 16);
      final y = _liftX(x);
      return _secp256k1.curve.createPoint(x, y);
    }
    if (normalized.length == 66 &&
        (normalized.startsWith('02') || normalized.startsWith('03'))) {
      final x = BigInt.parse(normalized.substring(2), radix: 16);
      final y = _liftX(x);
      final point = _secp256k1.curve.createPoint(x, y);
      if ((normalized.startsWith('03')) != !y.isEven) {
        return _secp256k1.curve.createPoint(x, _secp256k1Prime - y);
      }
      return point;
    }
    if (normalized.length == 130 && normalized.startsWith('04')) {
      final x = BigInt.parse(normalized.substring(2, 66), radix: 16);
      final y = BigInt.parse(normalized.substring(66), radix: 16);
      return _secp256k1.curve.createPoint(x, y);
    }
    throw FormatException('Unsupported public key format: $publicKeyHex');
  }

  static BigInt _liftX(BigInt x) {
    final p = _secp256k1Prime;
    final ySquared = (x.modPow(BigInt.from(3), p) + BigInt.from(7)) % p;
    final y = ySquared.modPow((p + BigInt.one) ~/ BigInt.from(4), p);
    if (y.modPow(BigInt.two, p) != ySquared) {
      throw FormatException('Unable to recover Y from X for secp256k1');
    }
    return (y % BigInt.two == BigInt.zero) ? y : p - y;
  }

  static Uint8List _ecdhSharedX(BigInt privateKey, ECPoint peerPoint) {
    final shared = peerPoint * privateKey;
    if (shared == null || shared.x == null) {
      throw StateError('Unable to derive shared secret');
    }
    return _toFixedLengthBytes(shared.x!.toBigInteger()!, 32);
  }

  static Uint8List _publicKeyXBytes(String publicKeyHex) {
    final normalized = publicKeyHex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (normalized.length == 64) {
      return Uint8List.fromList(hex.decode(normalized));
    }
    if (normalized.length == 66 &&
        (normalized.startsWith('02') || normalized.startsWith('03'))) {
      return Uint8List.fromList(hex.decode(normalized.substring(2)));
    }
    if (normalized.length == 130 && normalized.startsWith('04')) {
      return Uint8List.fromList(hex.decode(normalized.substring(2, 66)));
    }
    throw FormatException('Unsupported public key format: $publicKeyHex');
  }

  static Uint8List _compressedPublicKeyBytes(ECPoint point) {
    final x = point.x!.toBigInteger()!;
    final y = point.y!.toBigInteger()!;
    final prefix = y.isEven ? 0x02 : 0x03;
    return Uint8List.fromList([prefix, ..._toFixedLengthBytes(x, 32)]);
  }

  static Uint8List _toFixedLengthBytes(BigInt value, int length) {
    final hexText = value.toRadixString(16).padLeft(length * 2, '0');
    return Uint8List.fromList(hex.decode(hexText));
  }
}
