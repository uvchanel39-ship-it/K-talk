import 'dart:typed_data';

import 'package:convert/convert.dart';

import '../kaspa/kaspa.dart';
import 'kns_inscription_script.dart';
import 'kns_profile.dart';
import 'kns_service.dart';

class KnsProfileUpdateResult {
  const KnsProfileUpdateResult({
    required this.commitTxId,
    required this.revealTxId,
    required this.verified,
  });

  final String commitTxId;
  final String revealTxId;
  final bool verified;
}

class KnsInscriptionService {
  KnsInscriptionService({
    required this.walletService,
    required this.cache,
    required this.knsService,
    required this.ownerAddress,
    required this.feeRate,
  });

  static final _profileCommitAmount = BigInt.from(200000000);
  static final _profileRevealAmount = BigInt.from(100000000);
  static final _priorityFee = BigInt.from(2000000);
  static const _maxStandardMass = 100000;

  final WalletService walletService;
  final KnsProfileCacheStore cache;
  final KnsService knsService;
  final Address ownerAddress;
  final int feeRate;

  Future<KnsProfileUpdateResult> updateProfileField({
    required String assetId,
    required String fieldKey,
    required String value,
  }) async {
    final pending = cache.getPendingCommit(ownerAddress.encoded);
    if (pending != null) await _submitPendingReveal(pending);

    final payload = KnsInscriptionScript.buildProfilePayload(
      assetId: assetId,
      fieldKey: fieldKey,
      value: value,
    );
    final redeemScript = KnsInscriptionScript.buildRedeemScript(
      ownerAddress.scriptAddress(),
      'kns',
      payload,
    );
    final commitAddress = KnsInscriptionScript.commitAddress(
      prefix: ownerAddress.prefix,
      redeemScript: redeemScript,
    );
    final spendableUtxos = (await walletService.rpc.getUtxosByAddresses([
      ownerAddress.encoded,
    ])).toList(growable: false);
    if (spendableUtxos.isEmpty) {
      throw StateError('No spendable UTXOs available for KNS profile update');
    }

    final commitTx = walletService.createSendTx(
      toAddress: commitAddress,
      amount: .raw(_profileCommitAmount),
      spendableUtxos: spendableUtxos,
      feeRate: feeRate,
      changeAddress: ownerAddress,
      note: 'kns-profile',
    );
    final commitTxId = await walletService.sendTransaction(commitTx.tx);
    final commitScript = payToAddressScript(commitAddress).scriptPublicKey;
    final record = KnsPendingCommit(
      address: ownerAddress.encoded,
      commitTxId: commitTxId,
      redeemScriptHex: hex.encode(redeemScript),
      commitScriptPubKeyHex: hex.encode(commitScript),
      commitAmountSompi: _profileCommitAmount.toInt(),
      revealAmountSompi: _profileRevealAmount.toInt(),
      assetId: assetId,
      fieldKey: fieldKey,
      value: value.trim(),
    );
    await cache.putPendingCommit(record);

    final revealTxId = await _submitPendingReveal(record);
    await cache.invalidate(ownerAddress.encoded);
    final verified = await knsService.verifyProfileField(
      assetId: assetId,
      fieldKey: fieldKey,
      expectedValue: value.trim(),
    );
    return KnsProfileUpdateResult(
      commitTxId: commitTxId,
      revealTxId: revealTxId,
      verified: verified,
    );
  }

  Future<String> _submitPendingReveal(KnsPendingCommit pending) async {
    final redeemScript = hex.decode(pending.redeemScriptHex);
    final commitAddress = KnsInscriptionScript.commitAddress(
      prefix: ownerAddress.prefix,
      redeemScript: Uint8List.fromList(redeemScript),
    );
    final expectedCommitScript = payToAddressScript(commitAddress);
    if (hex.encode(expectedCommitScript.scriptPublicKey) !=
        pending.commitScriptPubKeyHex) {
      throw const FormatException('Pending KNS commit script does not match');
    }
    final scriptPublicKey = ScriptPublicKey(
      scriptPublicKey: expectedCommitScript.scriptPublicKey,
      version: 0,
    );
    final commitUtxoEntry = UtxoEntry(
      amount: BigInt.from(pending.commitAmountSompi),
      scriptPublicKey: scriptPublicKey,
      blockDaaScore: BigInt.zero,
      isCoinbase: false,
    );
    final commitOutpoint = Outpoint(
      transactionId: pending.commitTxId,
      index: 0,
    );
    final signatureScriptSize =
        66 + KnsInscriptionScript.canonicalPushSize(redeemScript.length);
    final baseOutput = RawOutput(
      value: BigInt.from(pending.revealAmountSompi),
      scriptPublicKey: payToAddressScript(ownerAddress),
    );
    final availableForChangeAndFee = BigInt.from(
      pending.commitAmountSompi - pending.revealAmountSompi,
    );

    RawTransaction buildTransaction(List<RawOutput> outputs) => RawTransaction(
      version: 0,
      inputs: [
        RawInput(
          address: ownerAddress,
          previousOutpoint: commitOutpoint,
          signatureScript: Uint8List(signatureScriptSize),
          sequence: BigInt.zero,
          sigOpCount: 1,
          utxoEntry: commitUtxoEntry,
        ),
      ],
      outputs: outputs,
      lockTime: BigInt.zero,
      subnetworkId: kSubnetworkIdNative,
      gas: BigInt.zero,
    );

    BigInt feeFor(RawTransaction transaction) {
      final mass = MassCalculator.defaultCalculator.calcTxComputeMass(
        tx: transaction,
        minSignatures: 1,
      );
      if (mass > BigInt.from(_maxStandardMass)) {
        throw StateError('KNS reveal transaction exceeds standard mass');
      }
      return mass * BigInt.from(feeRate < 100 ? 100 : feeRate) + _priorityFee;
    }

    var outputs = <RawOutput>[baseOutput];
    final changeEstimate =
        availableForChangeAndFee -
        feeFor(
          buildTransaction([
            baseOutput,
            RawOutput(
              value: BigInt.one,
              scriptPublicKey: payToAddressScript(ownerAddress),
            ),
          ]),
        );
    final noChangeEstimate =
        availableForChangeAndFee - feeFor(buildTransaction([baseOutput]));
    final firstChangeEstimate = changeEstimate > BigInt.zero
        ? changeEstimate
        : noChangeEstimate;
    if (firstChangeEstimate > BigInt.zero) {
      final firstCandidate = RawOutput(
        value: firstChangeEstimate,
        scriptPublicKey: payToAddressScript(ownerAddress),
      );
      final firstTransaction = buildTransaction([baseOutput, firstCandidate]);
      final exactChange = availableForChangeAndFee - feeFor(firstTransaction);
      if (exactChange > BigInt.zero) {
        final exactCandidate = RawOutput(
          value: exactChange,
          scriptPublicKey: payToAddressScript(ownerAddress),
        );
        final candidate = buildTransaction([baseOutput, exactCandidate]);
        if (MassCalculator.defaultCalculator.calcTxStorageMass(tx: candidate) <=
            BigInt.from(_maxStandardMass)) {
          outputs.add(exactCandidate);
        }
      }
    }

    final transaction = buildTransaction(outputs);
    if (transaction.fee < feeFor(transaction)) {
      throw StateError('KNS reveal amount cannot cover its network fee');
    }
    final signatureHash = getSchnorrSignatureHash(
      tx: transaction,
      inputIndex: 0,
      hashType: SigHashType.sigHashAll,
      reusedValues: SigHashReusedValues(),
    );
    final signature = await walletService.signer.sign(
      signatureHash,
      ownerAddress,
    );
    final signatureScript = BytesBuilder()
      ..add([signature.length + 1])
      ..add(signature)
      ..add([SigHashType.sigHashAll.raw])
      ..add(
        KnsInscriptionScript.canonicalPush(Uint8List.fromList(redeemScript)),
      );
    transaction.inputs[0].signatureScript.setAll(
      0,
      signatureScript.takeBytes(),
    );

    try {
      final txId = await walletService.rpc.submitTransaction(transaction);
      await cache.clearPendingCommit(pending.address);
      return txId;
    } catch (error) {
      if (!error.toString().toLowerCase().contains('orphan')) rethrow;
      final txId = await walletService.rpc.submitTransaction(
        transaction,
        allowOrphan: true,
      );
      await cache.clearPendingCommit(pending.address);
      return txId;
    }
  }
}
