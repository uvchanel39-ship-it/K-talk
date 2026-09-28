import 'package:freezed_annotation/freezed_annotation.dart';

part 'contact.freezed.dart';
part 'contact.g.dart';

@freezed
sealed class Contact with _$Contact {
  const factory Contact({
    required String name,
    required String address,
    String? knsName,
    String? knsAssetId,
    String? avatarUrl,
    int? profileFetchedAtMs,
  }) = _Contact;

  factory Contact.fromJson(Map<String, dynamic> json) =>
      _$ContactFromJson(json);
}
