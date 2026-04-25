// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'activity_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
ActivityItem _$ActivityItemFromJson(
  Map<String, dynamic> json
) {
        switch (json['runtimeType']) {
                  case 'customer':
          return _CustomerActivity.fromJson(
            json
          );
                case 'vendor':
          return _VendorActivity.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'runtimeType',
  'ActivityItem',
  'Invalid union type "${json['runtimeType']}"!'
);
        }
      
}

/// @nodoc
mixin _$ActivityItem {

 String get id; String get entityName; DateTime get transactionDate; double get amount; String? get displayId; double? get balanceDue;
/// Create a copy of ActivityItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ActivityItemCopyWith<ActivityItem> get copyWith => _$ActivityItemCopyWithImpl<ActivityItem>(this as ActivityItem, _$identity);

  /// Serializes this ActivityItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ActivityItem&&(identical(other.id, id) || other.id == id)&&(identical(other.entityName, entityName) || other.entityName == entityName)&&(identical(other.transactionDate, transactionDate) || other.transactionDate == transactionDate)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.displayId, displayId) || other.displayId == displayId)&&(identical(other.balanceDue, balanceDue) || other.balanceDue == balanceDue));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,entityName,transactionDate,amount,displayId,balanceDue);

@override
String toString() {
  return 'ActivityItem(id: $id, entityName: $entityName, transactionDate: $transactionDate, amount: $amount, displayId: $displayId, balanceDue: $balanceDue)';
}


}

/// @nodoc
abstract mixin class $ActivityItemCopyWith<$Res>  {
  factory $ActivityItemCopyWith(ActivityItem value, $Res Function(ActivityItem) _then) = _$ActivityItemCopyWithImpl;
@useResult
$Res call({
 String id, String entityName, DateTime transactionDate, double amount, String? displayId, double? balanceDue
});




}
/// @nodoc
class _$ActivityItemCopyWithImpl<$Res>
    implements $ActivityItemCopyWith<$Res> {
  _$ActivityItemCopyWithImpl(this._self, this._then);

  final ActivityItem _self;
  final $Res Function(ActivityItem) _then;

/// Create a copy of ActivityItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? entityName = null,Object? transactionDate = null,Object? amount = null,Object? displayId = freezed,Object? balanceDue = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,entityName: null == entityName ? _self.entityName : entityName // ignore: cast_nullable_to_non_nullable
as String,transactionDate: null == transactionDate ? _self.transactionDate : transactionDate // ignore: cast_nullable_to_non_nullable
as DateTime,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,displayId: freezed == displayId ? _self.displayId : displayId // ignore: cast_nullable_to_non_nullable
as String?,balanceDue: freezed == balanceDue ? _self.balanceDue : balanceDue // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [ActivityItem].
extension ActivityItemPatterns on ActivityItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _CustomerActivity value)?  customer,TResult Function( _VendorActivity value)?  vendor,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CustomerActivity() when customer != null:
return customer(_that);case _VendorActivity() when vendor != null:
return vendor(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _CustomerActivity value)  customer,required TResult Function( _VendorActivity value)  vendor,}){
final _that = this;
switch (_that) {
case _CustomerActivity():
return customer(_that);case _VendorActivity():
return vendor(_that);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _CustomerActivity value)?  customer,TResult? Function( _VendorActivity value)?  vendor,}){
final _that = this;
switch (_that) {
case _CustomerActivity() when customer != null:
return customer(_that);case _VendorActivity() when vendor != null:
return vendor(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String id,  String entityName,  DateTime transactionDate,  double amount,  String? displayId,  String transactionType,  double? balanceDue)?  customer,TResult Function( String id,  String entityName,  DateTime transactionDate,  double amount,  String? displayId,  bool isPaid,  double? balanceDue,  double totalPriceHike)?  vendor,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CustomerActivity() when customer != null:
return customer(_that.id,_that.entityName,_that.transactionDate,_that.amount,_that.displayId,_that.transactionType,_that.balanceDue);case _VendorActivity() when vendor != null:
return vendor(_that.id,_that.entityName,_that.transactionDate,_that.amount,_that.displayId,_that.isPaid,_that.balanceDue,_that.totalPriceHike);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String id,  String entityName,  DateTime transactionDate,  double amount,  String? displayId,  String transactionType,  double? balanceDue)  customer,required TResult Function( String id,  String entityName,  DateTime transactionDate,  double amount,  String? displayId,  bool isPaid,  double? balanceDue,  double totalPriceHike)  vendor,}) {final _that = this;
switch (_that) {
case _CustomerActivity():
return customer(_that.id,_that.entityName,_that.transactionDate,_that.amount,_that.displayId,_that.transactionType,_that.balanceDue);case _VendorActivity():
return vendor(_that.id,_that.entityName,_that.transactionDate,_that.amount,_that.displayId,_that.isPaid,_that.balanceDue,_that.totalPriceHike);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String id,  String entityName,  DateTime transactionDate,  double amount,  String? displayId,  String transactionType,  double? balanceDue)?  customer,TResult? Function( String id,  String entityName,  DateTime transactionDate,  double amount,  String? displayId,  bool isPaid,  double? balanceDue,  double totalPriceHike)?  vendor,}) {final _that = this;
switch (_that) {
case _CustomerActivity() when customer != null:
return customer(_that.id,_that.entityName,_that.transactionDate,_that.amount,_that.displayId,_that.transactionType,_that.balanceDue);case _VendorActivity() when vendor != null:
return vendor(_that.id,_that.entityName,_that.transactionDate,_that.amount,_that.displayId,_that.isPaid,_that.balanceDue,_that.totalPriceHike);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CustomerActivity extends ActivityItem {
  const _CustomerActivity({required this.id, required this.entityName, required this.transactionDate, required this.amount, this.displayId, required this.transactionType, this.balanceDue, final  String? $type}): $type = $type ?? 'customer',super._();
  factory _CustomerActivity.fromJson(Map<String, dynamic> json) => _$CustomerActivityFromJson(json);

@override final  String id;
@override final  String entityName;
@override final  DateTime transactionDate;
@override final  double amount;
@override final  String? displayId;
 final  String transactionType;
@override final  double? balanceDue;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of ActivityItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CustomerActivityCopyWith<_CustomerActivity> get copyWith => __$CustomerActivityCopyWithImpl<_CustomerActivity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CustomerActivityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CustomerActivity&&(identical(other.id, id) || other.id == id)&&(identical(other.entityName, entityName) || other.entityName == entityName)&&(identical(other.transactionDate, transactionDate) || other.transactionDate == transactionDate)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.displayId, displayId) || other.displayId == displayId)&&(identical(other.transactionType, transactionType) || other.transactionType == transactionType)&&(identical(other.balanceDue, balanceDue) || other.balanceDue == balanceDue));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,entityName,transactionDate,amount,displayId,transactionType,balanceDue);

@override
String toString() {
  return 'ActivityItem.customer(id: $id, entityName: $entityName, transactionDate: $transactionDate, amount: $amount, displayId: $displayId, transactionType: $transactionType, balanceDue: $balanceDue)';
}


}

/// @nodoc
abstract mixin class _$CustomerActivityCopyWith<$Res> implements $ActivityItemCopyWith<$Res> {
  factory _$CustomerActivityCopyWith(_CustomerActivity value, $Res Function(_CustomerActivity) _then) = __$CustomerActivityCopyWithImpl;
@override @useResult
$Res call({
 String id, String entityName, DateTime transactionDate, double amount, String? displayId, String transactionType, double? balanceDue
});




}
/// @nodoc
class __$CustomerActivityCopyWithImpl<$Res>
    implements _$CustomerActivityCopyWith<$Res> {
  __$CustomerActivityCopyWithImpl(this._self, this._then);

  final _CustomerActivity _self;
  final $Res Function(_CustomerActivity) _then;

/// Create a copy of ActivityItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? entityName = null,Object? transactionDate = null,Object? amount = null,Object? displayId = freezed,Object? transactionType = null,Object? balanceDue = freezed,}) {
  return _then(_CustomerActivity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,entityName: null == entityName ? _self.entityName : entityName // ignore: cast_nullable_to_non_nullable
as String,transactionDate: null == transactionDate ? _self.transactionDate : transactionDate // ignore: cast_nullable_to_non_nullable
as DateTime,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,displayId: freezed == displayId ? _self.displayId : displayId // ignore: cast_nullable_to_non_nullable
as String?,transactionType: null == transactionType ? _self.transactionType : transactionType // ignore: cast_nullable_to_non_nullable
as String,balanceDue: freezed == balanceDue ? _self.balanceDue : balanceDue // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class _VendorActivity extends ActivityItem {
  const _VendorActivity({required this.id, required this.entityName, required this.transactionDate, required this.amount, this.displayId, required this.isPaid, this.balanceDue, this.totalPriceHike = 0.0, final  String? $type}): $type = $type ?? 'vendor',super._();
  factory _VendorActivity.fromJson(Map<String, dynamic> json) => _$VendorActivityFromJson(json);

@override final  String id;
@override final  String entityName;
@override final  DateTime transactionDate;
@override final  double amount;
@override final  String? displayId;
 final  bool isPaid;
@override final  double? balanceDue;
@JsonKey() final  double totalPriceHike;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of ActivityItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VendorActivityCopyWith<_VendorActivity> get copyWith => __$VendorActivityCopyWithImpl<_VendorActivity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VendorActivityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VendorActivity&&(identical(other.id, id) || other.id == id)&&(identical(other.entityName, entityName) || other.entityName == entityName)&&(identical(other.transactionDate, transactionDate) || other.transactionDate == transactionDate)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.displayId, displayId) || other.displayId == displayId)&&(identical(other.isPaid, isPaid) || other.isPaid == isPaid)&&(identical(other.balanceDue, balanceDue) || other.balanceDue == balanceDue)&&(identical(other.totalPriceHike, totalPriceHike) || other.totalPriceHike == totalPriceHike));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,entityName,transactionDate,amount,displayId,isPaid,balanceDue,totalPriceHike);

@override
String toString() {
  return 'ActivityItem.vendor(id: $id, entityName: $entityName, transactionDate: $transactionDate, amount: $amount, displayId: $displayId, isPaid: $isPaid, balanceDue: $balanceDue, totalPriceHike: $totalPriceHike)';
}


}

/// @nodoc
abstract mixin class _$VendorActivityCopyWith<$Res> implements $ActivityItemCopyWith<$Res> {
  factory _$VendorActivityCopyWith(_VendorActivity value, $Res Function(_VendorActivity) _then) = __$VendorActivityCopyWithImpl;
@override @useResult
$Res call({
 String id, String entityName, DateTime transactionDate, double amount, String? displayId, bool isPaid, double? balanceDue, double totalPriceHike
});




}
/// @nodoc
class __$VendorActivityCopyWithImpl<$Res>
    implements _$VendorActivityCopyWith<$Res> {
  __$VendorActivityCopyWithImpl(this._self, this._then);

  final _VendorActivity _self;
  final $Res Function(_VendorActivity) _then;

/// Create a copy of ActivityItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? entityName = null,Object? transactionDate = null,Object? amount = null,Object? displayId = freezed,Object? isPaid = null,Object? balanceDue = freezed,Object? totalPriceHike = null,}) {
  return _then(_VendorActivity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,entityName: null == entityName ? _self.entityName : entityName // ignore: cast_nullable_to_non_nullable
as String,transactionDate: null == transactionDate ? _self.transactionDate : transactionDate // ignore: cast_nullable_to_non_nullable
as DateTime,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,displayId: freezed == displayId ? _self.displayId : displayId // ignore: cast_nullable_to_non_nullable
as String?,isPaid: null == isPaid ? _self.isPaid : isPaid // ignore: cast_nullable_to_non_nullable
as bool,balanceDue: freezed == balanceDue ? _self.balanceDue : balanceDue // ignore: cast_nullable_to_non_nullable
as double?,totalPriceHike: null == totalPriceHike ? _self.totalPriceHike : totalPriceHike // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
