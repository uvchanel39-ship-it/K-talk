import 'package:flutter_test/flutter_test.dart';
import 'package:kaspium_wallet/contacts/contact.dart';
import 'package:kaspium_wallet/discovery/discovery_utils.dart';

void main() {
  group('Discovery contact filters', () {
    final contacts = [
      const Contact(name: 'Alicia', address: 'kaspa:aaa'),
      const Contact(name: 'Bruno', address: 'kaspa:bbb'),
      const Contact(name: 'Charlie', address: 'kaspa:ccc'),
    ];

    test('matches contact name or address when searching', () {
      final filtered = filterContactsForDiscovery(contacts, 'br');

      expect(filtered, hasLength(1));
      expect(filtered.first.name, 'Bruno');
    });

    test('matches address when name is not enough', () {
      final filtered = filterContactsForDiscovery(contacts, 'aaa');

      expect(filtered, hasLength(1));
      expect(filtered.first.address, 'kaspa:aaa');
    });

    test('sorts by last seen time before alphabetical fallback', () {
      final lastSeenByAddress = {
        'kaspa:aaa': DateTime(2024, 1, 1),
        'kaspa:bbb': DateTime(2024, 2, 1),
        'kaspa:ccc': DateTime(2024, 3, 1),
      };

      final sorted = sortContactsForDiscovery(
        contacts,
        DiscoverySort.lastSeen,
        lastSeenByAddress,
      );

      expect(sorted.map((contact) => contact.name).toList(), [
        'Charlie',
        'Bruno',
        'Alicia',
      ]);
    });

    test('sorts alphabetically when chosen', () {
      final sorted = sortContactsForDiscovery(
        contacts,
        DiscoverySort.alphabetical,
        const {},
      );

      expect(sorted.map((contact) => contact.name).toList(), [
        'Alicia',
        'Bruno',
        'Charlie',
      ]);
    });
  });
}
