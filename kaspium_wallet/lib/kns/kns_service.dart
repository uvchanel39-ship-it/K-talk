import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../kaspa/transaction.dart';
import 'kns_profile.dart';

typedef KnsMessageSigner =
    Future<Uint8List> Function(
      String address,
      Uint8List data,
    );

class KnsService {
  KnsService({
    required this.cache,
    required this.signer,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static final _baseUri = Uri.https(
    'api.knsdomains.org',
    '/mainnet/api/v1/',
  );

  final KnsProfileCacheStore cache;
  final KnsMessageSigner signer;
  final http.Client _client;

  static Uint8List prepareImageForUpload(Uint8List source) {
    final decoded = img.decodeImage(source);
    if (decoded == null) throw const FormatException('Unable to decode image');
    final longest = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    final resized = longest > 1400
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height
                ? 1400
                : (decoded.width * 1400 / decoded.height).round(),
            height: decoded.height >= decoded.width
                ? 1400
                : (decoded.height * 1400 / decoded.width).round(),
          )
        : decoded;
    return Uint8List.fromList(img.encodePng(resized));
  }

  Future<String?> cacheAvatar({
    required String address,
    required String avatarUrl,
  }) => cache.cacheAvatar(
    address: address,
    avatarUrl: avatarUrl,
    client: _client,
  );

  Future<KnsProfile?> profileForAddress(
    String address, {
    String? currentSelection,
    bool forceRefresh = false,
  }) async {
    final normalized = address.trim().toLowerCase();
    if (!normalized.startsWith('kaspa:')) return null;

    final cached = cache.get(normalized);
    if (!forceRefresh && cached != null && cache.isFresh(cached)) {
      return cached;
    }

    try {
      final assetsJson = await _getJson(
        _baseUri.replace(
          path: '${_baseUri.path}assets',
          queryParameters: {
            'owner': normalized,
            'type': 'domain',
            'pageSize': '100',
          },
        ),
        allowNotFound: true,
      );
      final assets =
          ((assetsJson?['data'] as Map?)?['assets'] as List?)
              ?.whereType<Map>()
              .where(
                (asset) =>
                    asset['isDomain'] == true &&
                    asset['isVerifiedDomain'] == true &&
                    asset['asset'] is String &&
                    asset['assetId'] is String,
              )
              .toList(growable: false) ??
          const <Map>[];

      if (assets.isEmpty) {
        final empty = KnsProfile(
          address: normalized,
          fetchedAtMs: DateTime.now().millisecondsSinceEpoch,
        );
        await cache.put(empty);
        return empty;
      }

      final primaryJson = await _getJson(
        _baseUri.replace(path: '${_baseUri.path}primary-name/$normalized'),
        allowNotFound: true,
      );
      final primary =
          (((primaryJson?['data'] as Map?)?['domain'] as Map?)?['fullName']
                  as String?)
              ?.toLowerCase();
      final selected = currentSelection?.trim().toLowerCase();
      final activeAsset = assets.firstWhere(
        (asset) => asset['asset'] == selected,
        orElse: () => assets.firstWhere(
          (asset) => asset['asset'] == primary,
          orElse: () => assets.first,
        ),
      );
      final domain = activeAsset['asset'] as String;
      final assetId = activeAsset['assetId'] as String;
      final profileJson = await _getJson(
        _baseUri.replace(path: '${_baseUri.path}domain/$assetId/profile'),
        allowNotFound: true,
      );
      final fields = (((profileJson?['data'] as Map?)?['profile']) as Map?);
      final profile = KnsProfile(
        address: normalized,
        domain: domain,
        assetId: assetId,
        avatarUrl: fields?['avatarUrl'] as String?,
        bannerUrl: fields?['bannerUrl'] as String?,
        bio: fields?['bio'] as String?,
        fetchedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      await cache.put(profile);
      return profile;
    } catch (_) {
      final failed = KnsProfile(
        address: normalized,
        domain: cached?.domain,
        assetId: cached?.assetId,
        avatarUrl: cached?.avatarUrl,
        bannerUrl: cached?.bannerUrl,
        bio: cached?.bio,
        fetchedAtMs: DateTime.now().millisecondsSinceEpoch,
        failed: true,
      );
      await cache.put(failed);
      return cached ?? failed;
    }
  }

  Future<String> uploadProfileImage({
    required String address,
    required String assetId,
    required Uint8List imageBytes,
    String uploadType = 'avatar',
  }) async {
    if (imageBytes.isEmpty) throw const FormatException('Image is empty');
    if (uploadType != 'avatar' && uploadType != 'banner') {
      throw ArgumentError.value(uploadType, 'uploadType');
    }

    final signMessage = jsonEncode({
      'assetId': assetId,
      'uploadType': uploadType,
    });
    Object? lastError;
    for (final mode in _SigningMode.values) {
      final messageBytes = Uint8List.fromList(utf8.encode(signMessage));
      final signingData = switch (mode) {
        _SigningMode.kaspaPersonalMessage => hashPersonalMessage(signMessage),
        _SigningMode.rawUtf8 => messageBytes,
        _SigningMode.sha256Digest => Uint8List.fromList(
          sha256.convert(messageBytes).bytes,
        ),
      };
      final signature = hex.encode(await signer(address, signingData));
      try {
        final request =
            http.MultipartRequest(
                'POST',
                _baseUri.replace(path: '${_baseUri.path}upload/image'),
              )
              ..fields['signMessage'] = signMessage
              ..fields['signature'] = signature
              ..files.add(
                http.MultipartFile.fromBytes(
                  'image',
                  imageBytes,
                  filename: '$uploadType-$assetId.png',
                ),
              );
        final response = await http.Response.fromStream(
          await _client.send(request).timeout(const Duration(seconds: 45)),
        );
        final result = _decodeEnvelope(response);
        final outer = result['data'] as Map?;
        final inner = outer?['data'] as Map?;
        final imageUrl = inner?['imageUrl'] as String?;
        if (imageUrl == null || imageUrl.isEmpty) {
          throw const FormatException('KNS upload response has no image URL');
        }
        return imageUrl;
      } catch (error) {
        lastError = error;
        if (!_isSignatureFailure(error.toString()) ||
            mode == _SigningMode.values.last) {
          rethrow;
        }
      }
    }
    throw StateError('KNS image upload failed: $lastError');
  }

  Future<bool> verifyProfileField({
    required String assetId,
    required String fieldKey,
    required String expectedValue,
    int attempts = 30,
  }) async {
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    for (
      var attempt = 0;
      attempt < attempts && DateTime.now().isBefore(deadline);
      attempt++
    ) {
      try {
        final response = await _getJson(
          _baseUri.replace(path: '${_baseUri.path}domain/$assetId/profile'),
          allowNotFound: true,
          timeout: const Duration(seconds: 5),
        );
        final profile = ((response?['data'] as Map?)?['profile'] as Map?);
        if (profile?[fieldKey] == expectedValue) return true;
      } catch (_) {}
      if (attempt + 1 < attempts) {
        final remaining = deadline.difference(DateTime.now());
        if (remaining <= Duration.zero) break;
        await Future<void>.delayed(
          remaining < const Duration(seconds: 3)
              ? remaining
              : const Duration(seconds: 3),
        );
      }
    }
    return false;
  }

  Future<Map<String, dynamic>?> _getJson(
    Uri uri, {
    bool allowNotFound = false,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final response = await _client
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(timeout);
    if (allowNotFound && response.statusCode == 404) return null;
    return _decodeEnvelope(response);
  }

  Map<String, dynamic> _decodeEnvelope(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map
          ? (decoded['error'] ?? decoded['message'])?.toString()
          : null;
      throw http.ClientException(
        message?.isNotEmpty == true
            ? message!
            : 'KNS request failed (HTTP ${response.statusCode})',
        response.request?.url,
      );
    }
    if (decoded is! Map || decoded['success'] != true) {
      final message = decoded is Map
          ? (decoded['error'] ?? decoded['message'])?.toString()
          : null;
      throw FormatException(message ?? 'Invalid KNS response');
    }
    return Map<String, dynamic>.from(decoded);
  }

  bool _isSignatureFailure(String message) {
    final lower = message.toLowerCase();
    return lower.contains('signature verification failed') ||
        lower.contains('unauthorized');
  }
}

enum _SigningMode { kaspaPersonalMessage, rawUtf8, sha256Digest }
