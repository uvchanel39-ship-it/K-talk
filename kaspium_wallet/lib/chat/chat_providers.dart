import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:convert/convert.dart';

import '../app_providers.dart';
import '../kaspa/kaspa.dart';
import 'identity/chat_identity.dart';
import 'repository/chat_repository.dart';
import 'storage/chat_storage.dart';
import 'transport/chat_transport.dart';

final chatStorageProvider = FutureProvider.autoDispose<ChatStorage>((ref) async {
  return ChatStorage.open();
});

final chatRepositoryProvider = FutureProvider.autoDispose<ChatRepository>((ref) async {
  final storage = await ref.watch(chatStorageProvider.future);
  final addressNotifier = ref.watch(addressNotifierProvider);
  final network = ref.watch(networkProvider);

  final currentAddress = addressNotifier.receiveAddress.encoded;

  return ChatRepository(
    storage: storage,
    walletAdapter: KTalkWalletAdapter(
      address: currentAddress,
      network: network.name,
      publicKeyHex: hex.encode(Address.decodeAddress(currentAddress).scriptAddress()),
    ),
  );
});

final chatTransportProvider = Provider.autoDispose<ChatTransport>((ref) {
  final repo = ref.watch(chatRepositoryProvider).asData?.value;
  final walletService = ref.watch(walletServiceProvider);
  final apiService = ref.watch(kaspaApiServiceProvider);
  final addressNotifier = ref.watch(addressNotifierProvider);

  final address = addressNotifier.receiveAddress.encoded;
  final network = ref.watch(networkProvider);

  return ChatTransport(
    walletService: walletService,
    apiService: apiService,
    walletAddress: address,
    repository: repo,
    senderIdentity: ChatIdentity.fromWalletAdapter(
      KTalkWalletAdapter(
        address: address,
        network: network.name,
        publicKeyHex: hex.encode(Address.decodeAddress(address).scriptAddress()),
      ),
    ),
  );
});

final chatRevisionProvider = StateProvider.autoDispose<int>((ref) => 0);

final chatSyncProvider = FutureProvider.autoDispose<void>((ref) async {
  final repository = await ref.watch(chatRepositoryProvider.future);
  final transport = ref.watch(chatTransportProvider);
  final addresses = ref.read(addressNotifierProvider).allAddresses;
  final addressNotifier = ref.read(addressNotifierProvider);
  final walletAuth = ref.read(walletAuthProvider.notifier);

  Future<String> resolvePrivateKey(String address) async {
    final receiveIndex = addressNotifier.indexOfReceiveAddress(address);
    if (receiveIndex != null) {
      return walletAuth.privateKeyHexForAddress(
        typeIndex: 0,
        index: receiveIndex,
      );
    }
    final changeIndex = addressNotifier.indexOfChangeAddress(address);
    if (changeIndex != null) {
      return walletAuth.privateKeyHexForAddress(
        typeIndex: 1,
        index: changeIndex,
      );
    }
    throw StateError('K-talk address is not owned by the active wallet');
  }

  Future<void> sync() async {
    for (final address in addresses) {
      await transport.receive(
        address: address,
        privateKeyResolver: resolvePrivateKey,
        chatRepository: repository,
      );
    }
    ref.read(chatRevisionProvider.notifier).state++;
  }

  await sync();
  ref.listen(virtualChainChangedProvider, (_, next) {
    if (next.hasValue) {
      sync();
    }
  });
});
