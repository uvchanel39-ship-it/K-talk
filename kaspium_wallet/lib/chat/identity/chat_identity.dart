import '../../fee/fee_providers.dart';
import '../../kaspa/kaspa.dart';

class KTalkWalletAdapter {
  const KTalkWalletAdapter({
    required this.address,
    required this.network,
    this.publicKeyHex,
    this.createdAt,
    this.walletService,
    this.rpcService,
  });

  final String address;
  final String network;
  final String? publicKeyHex;
  final DateTime? createdAt;
  final WalletService? walletService;
  final RpcService? rpcService;

  AddressPrefix get addressPrefix => switch (network.toLowerCase()) {
        'kaspa-testnet' || 'kaspatest' || 'testnet' => AddressPrefix.kaspaTest,
        'kaspa-dev' || 'kaspadev' || 'devnet' => AddressPrefix.kaspaDev,
        'kaspa-sim' || 'kaspasim' || 'simnet' => AddressPrefix.kaspaSim,
        _ => AddressPrefix.kaspa,
      };

  bool get hasWalletBackend => walletService != null && rpcService != null;

  Address get walletAddress => Address.decodeAddress(address, addressPrefix);

  Future<String> sendChatPayload({
    required String recipientAddress,
    required Uint8List payload,
    int feeRate = kMinFeeRate,
    String? note,
  }) async {
    if (walletService == null || rpcService == null) {
      throw StateError('Wallet backend is not configured for KTalkWalletAdapter');
    }

    final sender = Address.decodeAddress(address, addressPrefix);
    final recipient = Address.decodeAddress(recipientAddress, addressPrefix);
    final spendableUtxos = (await rpcService!.getUtxosByAddresses([address])).toList();

    if (spendableUtxos.isEmpty) {
      throw StateError('No spendable UTXOs available for address $address');
    }

    final sendTx = walletService!.createSendTx(
      toAddress: recipient,
      amount: Amount.zero,
      spendableUtxos: spendableUtxos,
      feeRate: feeRate,
      changeAddress: sender,
      payload: payload,
      note: note ?? 'ktalk-chat',
    );

    return walletService!.sendTransaction(sendTx.tx);
  }

  Map<String, dynamic> toJson() => {
        'address': address,
        'network': network,
        'publicKeyHex': publicKeyHex,
        'createdAt': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
      };

  factory KTalkWalletAdapter.fromJson(Map<String, dynamic> json) => KTalkWalletAdapter(
        address: json['address'] as String? ?? json['kaspaAddress'] as String? ?? '',
        network: json['network'] as String? ?? 'kaspa-mainnet',
        publicKeyHex: json['publicKeyHex'] as String?,
        createdAt: json['createdAt'] == null ? null : DateTime.tryParse(json['createdAt'] as String),
      );
}

class ChatIdentity {
  const ChatIdentity({
    required this.kaspaAddress,
    required this.network,
    this.publicKeyHex,
    this.createdAt,
  });

  final String kaspaAddress;
  final String network;
  final String? publicKeyHex;
  final DateTime? createdAt;

  bool get hasPublicKey => publicKeyHex != null && publicKeyHex!.trim().isNotEmpty;

  factory ChatIdentity.fromWalletAdapter(KTalkWalletAdapter adapter) => ChatIdentity(
        kaspaAddress: adapter.address,
        network: adapter.network,
        publicKeyHex: adapter.publicKeyHex,
        createdAt: adapter.createdAt,
      );

  Map<String, dynamic> toJson() => {
        'kaspaAddress': kaspaAddress,
        'network': network,
        'publicKeyHex': publicKeyHex,
        'createdAt': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
      };

  factory ChatIdentity.fromJson(Map<String, dynamic> json) => ChatIdentity(
        kaspaAddress: json['kaspaAddress'] as String? ?? '',
        network: json['network'] as String? ?? 'kaspa-mainnet',
        publicKeyHex: json['publicKeyHex'] as String?,
        createdAt: json['createdAt'] == null ? null : DateTime.tryParse(json['createdAt'] as String),
      );

  @override
  String toString() => 'ChatIdentity(address: $kaspaAddress, network: $network)';
}
