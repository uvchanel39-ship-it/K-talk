import 'package:kaspium_wallet/contacts/contact.dart';

enum DiscoverySort { lastSeen, alphabetical }

List<Contact> filterContactsForDiscovery(List<Contact> contacts, String query) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) {
    return contacts;
  }

  return contacts
      .where((contact) {
        final name = contact.name.toLowerCase();
        final address = contact.address.toLowerCase();
        return name.contains(normalizedQuery) ||
            address.contains(normalizedQuery);
      })
      .toList(growable: false);
}

List<Contact> sortContactsForDiscovery(
  List<Contact> contacts,
  DiscoverySort sort,
  Map<String, DateTime> lastSeenByAddress,
) {
  final sorted = [...contacts];

  switch (sort) {
    case DiscoverySort.lastSeen:
      sorted.sort((left, right) {
        final leftSeen = lastSeenByAddress[left.address];
        final rightSeen = lastSeenByAddress[right.address];

        if (leftSeen == null && rightSeen == null) {
          return left.name.toLowerCase().compareTo(right.name.toLowerCase());
        }
        if (leftSeen == null) return 1;
        if (rightSeen == null) return -1;
        return rightSeen.compareTo(leftSeen);
      });
      break;
    case DiscoverySort.alphabetical:
      sorted.sort(
        (left, right) =>
            left.name.toLowerCase().compareTo(right.name.toLowerCase()),
      );
      break;
  }

  return sorted;
}
