import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../app_providers.dart';
import 'kns_inscription_service.dart';
import 'kns_profile.dart';
import 'kns_service.dart';

final knsProfileCacheProvider = Provider<KnsProfileCacheStore>((ref) {
  final database = ref.watch(dbProvider);
  return KnsProfileCacheStore(database.getGenericBox(database.settingsBox));
});

final knsServiceProvider = Provider.autoDispose<KnsService>((ref) {
  final cache = ref.watch(knsProfileCacheProvider);
  final addressNotifier = ref.watch(addressNotifierProvider);
  final walletAuth = ref.watch(walletAuthProvider.notifier);
  final client = http.Client();
  ref.onDispose(client.close);

  return KnsService(
    cache: cache,
    client: client,
    signer: (address, data) async {
      var typeIndex = 0;
      var index = addressNotifier.indexOfReceiveAddress(address);
      if (index == null) {
        typeIndex = 1;
        index = addressNotifier.indexOfChangeAddress(address);
      }
      if (index == null) {
        throw StateError('KNS address is not owned by this wallet');
      }
      return walletAuth.sign(data, typeIndex: typeIndex, index: index);
    },
  );
});

final knsProfileProvider = FutureProvider.autoDispose
    .family<KnsProfile?, String>((ref, address) async {
      final service = ref.watch(knsServiceProvider);
      final contacts = ref.read(contactsProvider);
      final contact = contacts.getContactWithAddress(address);
      final profile = await service.profileForAddress(
        address,
        currentSelection: contact?.knsName,
      );
      if (profile != null && !profile.failed) {
        await contacts.updateKnsProfile(address, profile);
      }
      return profile;
    });

final knsAvatarPathProvider = FutureProvider.autoDispose
    .family<String?, ({String address, String avatarUrl})>((ref, request) {
      return ref
          .watch(knsServiceProvider)
          .cacheAvatar(
            address: request.address,
            avatarUrl: request.avatarUrl,
          );
    });

final knsInscriptionServiceProvider =
    Provider.autoDispose<KnsInscriptionService>((ref) {
      final address = ref.watch(receiveAddressProvider);
      return KnsInscriptionService(
        walletService: ref.watch(walletServiceProvider),
        cache: ref.watch(knsProfileCacheProvider),
        knsService: ref.watch(knsServiceProvider),
        ownerAddress: address.address,
        feeRate: ref.watch(feeRateProvider),
      );
    });
