import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaspium_wallet/app_router.dart';
import 'package:kaspium_wallet/chat/crypto/kasia_cipher.dart';
import 'package:kaspium_wallet/chat/identity/chat_identity.dart';
import 'package:kaspium_wallet/chat/models/chat_message.dart';
import 'package:kaspium_wallet/chat/protocol/message_protocol.dart';
import 'package:kaspium_wallet/chat/repository/chat_repository.dart';
import 'package:kaspium_wallet/chat/services/chat_handshake_service.dart';
import 'package:kaspium_wallet/chat/storage/chat_storage.dart';
import 'package:hive/hive.dart';
import 'package:kaspium_wallet/chat/transport/chat_transport.dart';
import 'package:kaspium_wallet/kaspa/kaspa.dart';

class _TestSigner implements SignerBase {
  @override
  Future<bool> canSignForAddress(Address address) async => true;

  @override
  Future<Uint8List> sign(Uint8List data, Address address) async =>
      Uint8List.fromList(List<int>.filled(64, 0x11));
}

class _TestRpc extends RpcService {
  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<ServerInfo> getServerInfo() async => throw UnimplementedError();

  @override
  Future<Block> getBlock(String hash, {bool includeTransactions = false}) async =>
      throw UnimplementedError();

  @override
  Future<VirtualChainSegment> getVirtualChainFromBlockV2(
    String startHash, {
    DataVerbosity verbosity = DataVerbosity.full,
    int? minConfirmationCount,
  }) async => throw UnimplementedError();

  @override
  Future<Iterable<AddressBalance>> getBalancesByAddresses(Iterable<String> addresses) async => const [];

  @override
  Future<Iterable<Utxo>> getUtxosByAddresses(Iterable<String> addresses) async {
    final senderPrivateKey = KasiaCipher.generatePrivateKeyHex();
    final senderPublicKey = KasiaCipher.derivePublicKeyHex(senderPrivateKey);
    final senderKey = Uint8List.fromList(hex.decode(senderPublicKey.substring(2, 66)));
    final senderAddress = Address.publicKey(prefix: AddressPrefix.kaspa, publicKey: senderKey).encodeAddress();
    final utxo = Utxo(
      address: senderAddress,
      outpoint: Outpoint(transactionId: '01' * 32, index: 0),
      utxoEntry: UtxoEntry(
        amount: BigInt.from(1_000_000),
        scriptPublicKey: ScriptPublicKey(
          scriptPublicKey: Uint8List.fromList([0]),
          version: 0,
        ),
        blockDaaScore: BigInt.zero,
        isCoinbase: false,
      ),
    );
    return [utxo];
  }

  @override
  Future<Iterable<MempoolEntryByAddress>> getMempoolEntriesByAddresses(
    Iterable<String> addresses, {
    bool filterTransactionPool = false,
    bool includeOrphanPool = false,
  }) async => const [];

  @override
  Future<FeeEstimate> getFeeEstimate() async => throw UnimplementedError();

  @override
  Future<String> submitTransaction(RawTransaction transaction, {bool allowOrphan = false}) async => 'fake-tx-id';

  @override
  Future<(String, Transaction)> submitTransactionReplacement(RawTransaction transaction) async =>
      ('fake-tx-id', Transaction(
        transactionId: 'fake-tx-id',
        blockTime: 0,
        isAccepted: true,
        inputs: const [],
        outputs: const [],
      ));

  @override
  Stream<Block> notifyBlockAdded() => const Stream.empty();

  @override
  Future<void> stopNotifyingBlockAdded() async {}

  @override
  Stream<UtxosChanged> notifyUtxosChanged(Iterable<String> addresses) => const Stream.empty();

  @override
  Future<void> stopNotifyingUtxosChanged(Iterable<String> addresses) async {}

  @override
  Stream<BigInt> notifyVirtualDaaScoreChanged() => const Stream.empty();

  @override
  Future<void> stopNotifyingVirtualDaaScoreChanged() async {}

  @override
  Stream<BigInt> notifySinkBlueScoreChanged() => const Stream.empty();

  @override
  Future<void> stopNotifyingSinkBlueScoreChanged() async {}

  @override
  Stream<VirtualChainChanged> notifyVirtualChainChanged({bool includeAcceptedTransactionIds = false}) =>
      const Stream.empty();

  @override
  Future<void> stopNotifyingVirtualChainChanged() async {}
}

void main() {
  setUp(() async {
    Hive.init('/tmp/hive_ktalk_test');
    await Hive.close();
    await Hive.deleteFromDisk();
  });

  group('KTalk chat foundation', () {
    test('App starts at the KTalk splash route', () {
      expect(appRouter.initialRoute, equals('/'));
    });

    test('ChatIdentity is derived from wallet address and network', () {
      final adapter = KTalkWalletAdapter(
        address: 'kaspa:qqqtestaddress',
        network: 'kaspa-mainnet',
        publicKeyHex: '01' * 32,
      );

      final identity = ChatIdentity.fromWalletAdapter(adapter);

      expect(identity.kaspaAddress, 'kaspa:qqqtestaddress');
      expect(identity.network, 'kaspa-mainnet');
      expect(identity.publicKeyHex, '01' * 32);
    });

    test('MessageProtocol round-trips comm payload', () {
      final encrypted = EncryptedMessage(
        nonce: Uint8List(12),
        ephemeralPublicKey: Uint8List.fromList([0x02, ...List<int>.filled(32, 0)]),
        ciphertext: Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]),
      );

      final payload = MessageProtocol.serializeCommPayload(
        alias: 'alice',
        encrypted: encrypted,
      );

      final parsed = MessageProtocol.parseCommPayload(payload);
      expect(parsed, isNotNull);
      expect(parsed!.alias, 'alice');
      expect(parsed.message.nonce.length, 12);
      expect(parsed.message.ephemeralPublicKey.length, 33);
    });

    test('MessageProtocol round-trips handshake payload', () {
      final encrypted = EncryptedMessage(
        nonce: Uint8List(12),
        ephemeralPublicKey: Uint8List.fromList([0x03, ...List<int>.filled(32, 0)]),
        ciphertext: Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]),
      );

      final payload = MessageProtocol.serializeHandshakePayload(encrypted);
      final parsed = MessageProtocol.parseHandshakePayload(payload);

      expect(parsed, isNotNull);
      expect(parsed!.nonce.length, 12);
      expect(parsed.ephemeralPublicKey.length, 33);
    });

    test('KasiaCipher encrypt and decrypt round-trip the message', () {
      final privateKey = KasiaCipher.generatePrivateKeyHex();
      final publicKey = KasiaCipher.derivePublicKeyHex(privateKey);
      final encrypted = KasiaCipher.encrypt('hello from ktalk', publicKey);
      final decrypted = KasiaCipher.decrypt(encrypted, privateKey);

      expect(decrypted, 'hello from ktalk');
    });

    test('ChatHandshakeService creates and validates a valid handshake', () {
      final senderPrivateKey = KasiaCipher.generatePrivateKeyHex();
      final recipientPrivateKey = KasiaCipher.generatePrivateKeyHex();
      final recipientPublicKey = KasiaCipher.derivePublicKeyHex(recipientPrivateKey);

      final service = ChatHandshakeService();
      final handshake = service.createHandshake(
        senderAddress: 'kaspa:senderaddr',
        recipientAddress: 'kaspa:receiveraddr',
        senderPrivateKeyHex: senderPrivateKey,
        recipientPublicKeyHex: recipientPublicKey,
      );

      expect(service.validateHandshakePayload(handshake.payload), isTrue);
    });

    test('ChatMessage can serialize and restore from JSON', () {
      final message = ChatMessage(
        id: 'msg-1',
        sender: 'kaspa:alice',
        receiver: 'kaspa:bob',
        timestampMs: 1720000000000,
        messageType: ChatMessageType.text,
        encryptedPayload: 'payload-hex',
        status: ChatMessageStatus.sent,
      );

      final data = message.toJson();
      final restored = ChatMessage.fromJson(data);

      expect(restored.id, 'msg-1');
      expect(restored.sender, 'kaspa:alice');
      expect(restored.receiver, 'kaspa:bob');
      expect(restored.messageType, ChatMessageType.text);
      expect(restored.status, ChatMessageStatus.sent);
    });

    test('ChatStorage is idempotent and reuses the same open boxes', () async {
      final first = await ChatStorage.open();
      final second = await ChatStorage.open();

      expect(identical(first, second), isTrue);
      expect(Hive.isBoxOpen('_ktalk_conversations'), isTrue);
      expect(Hive.isBoxOpen('_ktalk_messages'), isTrue);
      expect(Hive.isBoxOpen('_ktalk_contacts'), isTrue);
      expect(Hive.isBoxOpen('_ktalk_handshakes'), isTrue);
    });

    test('ChatStorage persists messages and conversations without reopening boxes', () async {
      final storage = await ChatStorage.open();
      final message = ChatMessage(
        id: 'msg-reuse-1',
        sender: 'kaspa:alice',
        receiver: 'kaspa:bob',
        timestampMs: 1720000000000,
        messageType: ChatMessageType.text,
        encryptedPayload: 'payload-hex',
        status: ChatMessageStatus.sent,
      );

      await storage.saveMessage(message);
      final saved = storage.getMessages('kaspa:alice', 'kaspa:bob');

      expect(saved, hasLength(1));
      expect(saved.first.id, 'msg-reuse-1');
      expect(storage.getConversations(), isNotEmpty);
    });

    test('ChatTransport sends a real encrypted payload through the wallet backend', () async {
      final senderPrivateKey = KasiaCipher.generatePrivateKeyHex();
      final senderPublicKey = KasiaCipher.derivePublicKeyHex(senderPrivateKey);
      final senderAddress = Address.publicKey(
        prefix: AddressPrefix.kaspa,
        publicKey: Uint8List.fromList(hex.decode(senderPublicKey.substring(2, 66))),
      ).encodeAddress();

      final recipientPrivateKey = KasiaCipher.generatePrivateKeyHex();
      final recipientPublicKey = KasiaCipher.derivePublicKeyHex(recipientPrivateKey);
      final recipientAddress = Address.publicKey(
        prefix: AddressPrefix.kaspa,
        publicKey: Uint8List.fromList(hex.decode(recipientPublicKey.substring(2, 66))),
      ).encodeAddress();

      final transport = ChatTransport(
        walletService: WalletService(
          signer: _TestSigner(),
          rpc: _TestRpc(),
        ),
        apiService: ApiService.url('http://localhost'),
        walletAddress: senderAddress,
      );

      final sent = await transport.sendMessage(
        recipientAddress,
        'hello from K-Talk',
        recipientIdentity: ChatIdentity(
          kaspaAddress: recipientAddress,
          network: 'kaspa-mainnet',
          publicKeyHex: recipientPublicKey,
        ),
      );

      expect(sent.transactionId, 'fake-tx-id');
      expect(sent.status, ChatMessageStatus.sent);
      expect(sent.encryptedPayload, isNotEmpty);
      expect(sent.encryptedPayload, isNot('hello from K-Talk'));
    });

    test('ChatTransport receives a valid incoming K-Talk payload and saves it once', () async {
      final recipientPrivateKey = KasiaCipher.generatePrivateKeyHex();
      final recipientPublicKey = KasiaCipher.derivePublicKeyHex(recipientPrivateKey);
      final recipientAddress = Address.publicKey(
        prefix: AddressPrefix.kaspa,
        publicKey: Uint8List.fromList(hex.decode(recipientPublicKey.substring(2, 66))),
      ).encodeAddress();

      final encrypted = KasiaCipher.encrypt('hello from blockchain', recipientPublicKey);
      final payload = MessageProtocol.serializeCommPayload(
        alias: 'alice',
        encrypted: encrypted,
      );
      final txId = 'tx-${DateTime.now().microsecondsSinceEpoch}';

      final storage = ChatStorage.withBoxes(
        conversations: await Hive.openBox<dynamic>('_ktalk_conversations'),
        messages: await Hive.openBox<dynamic>('_ktalk_messages'),
        contacts: await Hive.openBox<dynamic>('_ktalk_contacts'),
        handshakes: await Hive.openBox<dynamic>('_ktalk_handshakes'),
      );
      final repo = ChatRepository(
        storage: storage,
        walletAdapter: KTalkWalletAdapter(
          address: recipientAddress,
          network: 'kaspa-mainnet',
          publicKeyHex: recipientPublicKey,
        ),
      );
      final transport = ChatTransport(
        walletService: WalletService(
          signer: _TestSigner(),
          rpc: _TestRpc(),
        ),
        apiService: ApiService.url('http://localhost'),
        walletAddress: recipientAddress,
        repository: repo,
      );

      final tx = Transaction(
        transactionId: txId,
        blockTime: 1710000000,
        isAccepted: true,
        inputs: const [],
        outputs: const [],
        payload: hex.encode(payload),
      );

      final received = await transport.receive(
        address: recipientAddress,
        transactions: [tx],
        privateKeyHex: recipientPrivateKey,
      );

      expect(received.length, 1);
      expect(received.first.transactionId, txId);
      expect(received.first.status, ChatMessageStatus.received);
      expect(received.first.metadata['plaintext'], 'hello from blockchain');
      expect(received.first.metadata['senderAlias'], 'alice');

      final deduped = await transport.receive(
        address: recipientAddress,
        transactions: [tx],
        privateKeyHex: recipientPrivateKey,
      );
      expect(deduped, isEmpty);
    });
  });
}
