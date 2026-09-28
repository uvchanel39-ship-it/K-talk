// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'contact.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Contact {

 String get name; String get address; String? get knsName; String? get knsAssetId; String? get avatarUrl; int? get profileFetchedAtMs;
/// Create a copy of Contact
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ContactCopyWith<Contact> get copyWith => _$ContactCopyWithImpl<Contact>(this as Contact, _$identity);

  /// Serializes this Contact to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Contact&&(identical(other.name, name) || other.name == name)&&(identical(other.address, address) || other.address == address)&&(identical(other.knsName, knsName) || other.knsName == knsName)&&(identical(other.knsAssetId, knsAssetId) || other.knsAssetId == knsAssetId)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.profileFetchedAtMs, profileFetchedAtMs) || other.profileFetchedAtMs == profileFetchedAtMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,address,knsName,knsAssetId,avatarUrl,profileFetchedAtMs);

@override
String toString() {
  return 'Contact(name: $name, address: $address, knsName: $knsName, knsAssetId: $knsAssetId, avatarUrl: $avatarUrl, profileFetchedAtMs: $profileFetchedAtMs)';
}


}

/// @nodoc
abstract mixin class $ContactCopyWith<$Res>  {
  factory $ContactCopyWith(Contact value, $Res Function(Contact) _then) = _$ContactCopyWithImpl;
@useResult
$Res call({
 String name, String address, String? knsName, String? knsAssetId, String? avatarUrl, int? profileFetchedAtMs
});




}
/// @nodoc
class _$ContactCopyWithImpl<$Res>
    implements $ContactCopyWith<$Res> {
  _$ContactCopyWithImpl(this._self, this._then);

  final Contact _self;
  final $Res Function(Contact) _then;

/// Create a copy of Contact
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? address = null,Object? knsName = freezed,Object? knsAssetId = freezed,Object? avatarUrl = freezed,Object? profileFetchedAtMs = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,address: null == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String,knsName: freezed == knsName ? _self.knsName : knsName // ignore: cast_nullable_to_non_nullable
as String?,knsAssetId: freezed == knsAssetId ? _self.knsAssetId : knsAssetId // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,profileFetchedAtMs: freezed == profileFetchedAtMs ? _self.profileFetchedAtMs : profileFetchedAtMs // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [Contact].
extension ContactPatterns on Contact {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Contact value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Contact() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Contact value)  $default,){
final _that = this;
switch (_that) {
case _Contact():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Contact value)?  $default,){
final _that = this;
switch (_that) {
case _Contact() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String address,  String? knsName,  String? knsAssetId,  String? avatarUrl,  int? profileFetchedAtMs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Contact() when $default != null:
return $default(_that.name,_that.address,_that.knsName,_that.knsAssetId,_that.avatarUrl,_that.profileFetchedAtMs);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String address,  String? knsName,  String? knsAssetId,  String? avatarUrl,  int? profileFetchedAtMs)  $default,) {final _that = this;
switch (_that) {
case _Contact():
return $default(_that.name,_that.address,_that.knsName,_that.knsAssetId,_that.avatarUrl,_that.profileFetchedAtMs);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String address,  String? knsName,  String? knsAssetId,  String? avatarUrl,  int? profileFetchedAtMs)?  $default,) {final _that = this;
switch (_that) {
case _Contact() when $default != null:
return $default(_that.name,_that.address,_that.knsName,_that.knsAssetId,_that.avatarUrl,_that.profileFetchedAtMs);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Contact implements Contact {
  const _Contact({required this.name, required this.address, this.knsName, this.knsAssetId, this.avatarUrl, this.profileFetchedAtMs});
  factory _Contact.fromJson(Map<String, dynamic> json) => _$ContactFromJson(json);

@override final  String name;
@override final  String address;
@override final  String? knsName;
@override final  String? knsAssetId;
@override final  String? avatarUrl;
@override final  int? profileFetchedAtMs;

/// Create a copy of Contact
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ContactCopyWith<_Contact> get copyWith => __$ContactCopyWithImpl<_Contact>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ContactToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Contact&&(identical(other.name, name) || other.name == name)&&(identical(other.address, address) || other.address == address)&&(identical(other.knsName, knsName) || other.knsName == knsName)&&(identical(other.knsAssetId, knsAssetId) || other.knsAssetId == knsAssetId)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.profileFetchedAtMs, profileFetchedAtMs) || other.profileFetchedAtMs == profileFetchedAtMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,address,knsName,knsAssetId,avatarUrl,profileFetchedAtMs);

@override
String toString() {
  return 'Contact(name: $name, address: $address, knsName: $knsName, knsAssetId: $knsAssetId, avatarUrl: $avatarUrl, profileFetchedAtMs: $profileFetchedAtMs)';
}


}

/// @nodoc
abstract mixin class _$ContactCopyWith<$Res> implements $ContactCopyWith<$Res> {
  factory _$ContactCopyWith(_Contact value, $Res Function(_Contact) _then) = __$ContactCopyWithImpl;
@override @useResult
$Res call({
 String name, String address, String? knsName, String? knsAssetId, String? avatarUrl, int? profileFetchedAtMs
});




}
/// @nodoc
class __$ContactCopyWithImpl<$Res>
    implements _$ContactCopyWith<$Res> {
  __$ContactCopyWithImpl(this._self, this._then);

  final _Contact _self;
  final $Res Function(_Contact) _then;

/// Create a copy of Contact
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? address = null,Object? knsName = freezed,Object? knsAssetId = freezed,Object? avatarUrl = freezed,Object? profileFetchedAtMs = freezed,}) {
  return _then(_Contact(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,address: null == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String,knsName: freezed == knsName ? _self.knsName : knsName // ignore: cast_nullable_to_non_nullable
as String?,knsAssetId: freezed == knsAssetId ? _self.knsAssetId : knsAssetId // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,profileFetchedAtMs: freezed == profileFetchedAtMs ? _self.profileFetchedAtMs : profileFetchedAtMs // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
