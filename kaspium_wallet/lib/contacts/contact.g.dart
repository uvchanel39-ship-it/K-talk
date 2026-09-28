// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contact.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Contact _$ContactFromJson(Map json) => _Contact(
  name: json['name'] as String,
  address: json['address'] as String,
  knsName: json['knsName'] as String?,
  knsAssetId: json['knsAssetId'] as String?,
  avatarUrl: json['avatarUrl'] as String?,
  profileFetchedAtMs: (json['profileFetchedAtMs'] as num?)?.toInt(),
);

Map<String, dynamic> _$ContactToJson(_Contact instance) => <String, dynamic>{
  'name': instance.name,
  'address': instance.address,
  'knsName': ?instance.knsName,
  'knsAssetId': ?instance.knsAssetId,
  'avatarUrl': ?instance.avatarUrl,
  'profileFetchedAtMs': ?instance.profileFetchedAtMs,
};
