import 'package:flutter_test/flutter_test.dart';
import 'package:kaspium_wallet/contacts/contact.dart';

void main() {
  test('legacy contacts load and KNS metadata preserves the local name', () {
    final contact = Contact.fromJson({
      'name': 'My local label',
      'address': 'kaspa:qrcontact',
    });

    final updated = contact.copyWith(
      knsName: 'alice.kas',
      knsAssetId: 'asset-id',
      avatarUrl: 'https://example.test/alice.png',
      profileFetchedAtMs: 123456,
    );

    expect(contact.knsName, isNull);
    expect(updated.name, 'My local label');
    expect(updated.address, contact.address);
    expect(updated.knsName, 'alice.kas');
    expect(updated.knsAssetId, 'asset-id');
    expect(updated.avatarUrl, 'https://example.test/alice.png');
  });
}
