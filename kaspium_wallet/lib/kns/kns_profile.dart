import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../database/boxes/generic_box.dart';

class KnsProfile {
  const KnsProfile({
    required this.address,
    required this.fetchedAtMs,
    this.domain,
    this.assetId,
    this.avatarUrl,
    this.bannerUrl,
    this.bio,
    this.failed = false,
  });

  final String address;
  final String? domain;
  final String? assetId;
  final String? avatarUrl;
  final String? bannerUrl;
  final String? bio;
  final int fetchedAtMs;
  final bool failed;

  bool get hasDomain => domain != null && assetId != null;

  Map<String, dynamic> toJson() => {
    'address': address,
    'domain': domain,
    'assetId': assetId,
    'avatarUrl': avatarUrl,
    'bannerUrl': bannerUrl,
    'bio': bio,
    'fetchedAtMs': fetchedAtMs,
    'failed': failed,
  };

  factory KnsProfile.fromJson(Map<String, dynamic> json) => KnsProfile(
    address: json['address'] as String? ?? '',
    domain: json['domain'] as String?,
    assetId: json['assetId'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
    bannerUrl: json['bannerUrl'] as String?,
    bio: json['bio'] as String?,
    fetchedAtMs: (json['fetchedAtMs'] as num?)?.toInt() ?? 0,
    failed: json['failed'] as bool? ?? false,
  );
}

class KnsPendingCommit {
  const KnsPendingCommit({
    required this.address,
    required this.commitTxId,
    required this.redeemScriptHex,
    required this.commitScriptPubKeyHex,
    required this.commitAmountSompi,
    required this.revealAmountSompi,
    required this.assetId,
    required this.fieldKey,
    required this.value,
  });

  final String address;
  final String commitTxId;
  final String redeemScriptHex;
  final String commitScriptPubKeyHex;
  final int commitAmountSompi;
  final int revealAmountSompi;
  final String assetId;
  final String fieldKey;
  final String value;

  Map<String, dynamic> toJson() => {
    'address': address,
    'commitTxId': commitTxId,
    'redeemScriptHex': redeemScriptHex,
    'commitScriptPubKeyHex': commitScriptPubKeyHex,
    'commitAmountSompi': commitAmountSompi,
    'revealAmountSompi': revealAmountSompi,
    'assetId': assetId,
    'fieldKey': fieldKey,
    'value': value,
  };

  factory KnsPendingCommit.fromJson(Map<String, dynamic> json) =>
      KnsPendingCommit(
        address: json['address'] as String? ?? '',
        commitTxId: json['commitTxId'] as String? ?? '',
        redeemScriptHex: json['redeemScriptHex'] as String? ?? '',
        commitScriptPubKeyHex: json['commitScriptPubKeyHex'] as String? ?? '',
        commitAmountSompi: (json['commitAmountSompi'] as num?)?.toInt() ?? 0,
        revealAmountSompi: (json['revealAmountSompi'] as num?)?.toInt() ?? 0,
        assetId: json['assetId'] as String? ?? '',
        fieldKey: json['fieldKey'] as String? ?? '',
        value: json['value'] as String? ?? '',
      );
}

class KnsProfileCacheStore {
  KnsProfileCacheStore(this._box);

  static const _keyPrefix = 'kachat_kns_profile:';
  static const _positiveTtlMs = 24 * 60 * 60 * 1000;
  static const _emptyTtlMs = 6 * 60 * 60 * 1000;
  static const _failureTtlMs = 10 * 60 * 1000;
  static const _maxAvatarBytes = 8 * 1024 * 1024;

  final GenericBox _box;
  final Map<String, Future<String?>> _avatarDownloads = {};

  String _key(String address) => '$_keyPrefix${address.trim().toLowerCase()}';
  String _pendingKey(String address) =>
      'kns_pending_commit:${address.trim().toLowerCase()}';

  KnsProfile? get(String address) {
    final json = _box.tryGet<Map<String, dynamic>>(
      _key(address),
      typeFactory: (value) => value,
    );
    return json == null ? null : KnsProfile.fromJson(json);
  }

  Future<void> put(KnsProfile profile) =>
      _box.set(_key(profile.address), profile.toJson());

  Future<void> invalidate(String address) => _box.remove(_key(address));

  KnsPendingCommit? getPendingCommit(String address) {
    final json = _box.tryGet<Map<String, dynamic>>(
      _pendingKey(address),
      typeFactory: (value) => value,
    );
    return json == null ? null : KnsPendingCommit.fromJson(json);
  }

  Future<void> putPendingCommit(KnsPendingCommit commit) =>
      _box.set(_pendingKey(commit.address), commit.toJson());

  Future<void> clearPendingCommit(String address) =>
      _box.remove(_pendingKey(address));

  bool isFresh(KnsProfile profile, {int? nowMs}) {
    final age =
        (nowMs ?? DateTime.now().millisecondsSinceEpoch) - profile.fetchedAtMs;
    final ttl = profile.failed
        ? _failureTtlMs
        : profile.hasDomain
        ? _positiveTtlMs
        : _emptyTtlMs;
    return age >= 0 && age < ttl;
  }

  Future<String?> cacheAvatar({
    required String address,
    required String avatarUrl,
    required http.Client client,
  }) {
    final key = address.trim().toLowerCase();
    return _avatarDownloads.putIfAbsent(key, () async {
      try {
        final uri = Uri.parse(avatarUrl);
        if (uri.scheme != 'https') return null;

        final directory = await getTemporaryDirectory();
        final avatarKey = sha256.convert(utf8.encode(key)).toString();
        final imageFile = File('${directory.path}/kns_avatars/$avatarKey.img');
        final urlFile = File('${directory.path}/kns_avatars/$avatarKey.url');
        final previousUrl = await urlFile.exists()
            ? await urlFile.readAsString()
            : null;
        if (previousUrl == avatarUrl && await imageFile.exists()) {
          return imageFile.path;
        }

        final response = await client
            .get(uri)
            .timeout(const Duration(seconds: 20));
        if (response.statusCode != 200 ||
            response.bodyBytes.isEmpty ||
            response.bodyBytes.length > _maxAvatarBytes ||
            !(response.headers['content-type'] ?? '').toLowerCase().startsWith(
              'image/',
            )) {
          return await imageFile.exists() ? imageFile.path : null;
        }

        await imageFile.parent.create(recursive: true);
        final temporaryFile = File('${imageFile.path}.part');
        await temporaryFile.writeAsBytes(response.bodyBytes, flush: true);
        await temporaryFile.rename(imageFile.path);
        await urlFile.writeAsString(avatarUrl, flush: true);
        return imageFile.path;
      } catch (_) {
        return null;
      } finally {
        _avatarDownloads.remove(key);
      }
    });
  }
}
