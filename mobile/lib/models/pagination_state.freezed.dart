// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pagination_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PaginationCursor {

 String get lastId; dynamic get lastValue; String get direction;
/// Create a copy of PaginationCursor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaginationCursorCopyWith<PaginationCursor> get copyWith => _$PaginationCursorCopyWithImpl<PaginationCursor>(this as PaginationCursor, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaginationCursor&&(identical(other.lastId, lastId) || other.lastId == lastId)&&const DeepCollectionEquality().equals(other.lastValue, lastValue)&&(identical(other.direction, direction) || other.direction == direction));
}


@override
int get hashCode => Object.hash(runtimeType,lastId,const DeepCollectionEquality().hash(lastValue),direction);

@override
String toString() {
  return 'PaginationCursor(lastId: $lastId, lastValue: $lastValue, direction: $direction)';
}


}

/// @nodoc
abstract mixin class $PaginationCursorCopyWith<$Res>  {
  factory $PaginationCursorCopyWith(PaginationCursor value, $Res Function(PaginationCursor) _then) = _$PaginationCursorCopyWithImpl;
@useResult
$Res call({
 String lastId, dynamic lastValue, String direction
});




}
/// @nodoc
class _$PaginationCursorCopyWithImpl<$Res>
    implements $PaginationCursorCopyWith<$Res> {
  _$PaginationCursorCopyWithImpl(this._self, this._then);

  final PaginationCursor _self;
  final $Res Function(PaginationCursor) _then;

/// Create a copy of PaginationCursor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? lastId = null,Object? lastValue = freezed,Object? direction = null,}) {
  return _then(_self.copyWith(
lastId: null == lastId ? _self.lastId : lastId // ignore: cast_nullable_to_non_nullable
as String,lastValue: freezed == lastValue ? _self.lastValue : lastValue // ignore: cast_nullable_to_non_nullable
as dynamic,direction: null == direction ? _self.direction : direction // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PaginationCursor].
extension PaginationCursorPatterns on PaginationCursor {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaginationCursor value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaginationCursor() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaginationCursor value)  $default,){
final _that = this;
switch (_that) {
case _PaginationCursor():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaginationCursor value)?  $default,){
final _that = this;
switch (_that) {
case _PaginationCursor() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String lastId,  dynamic lastValue,  String direction)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaginationCursor() when $default != null:
return $default(_that.lastId,_that.lastValue,_that.direction);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String lastId,  dynamic lastValue,  String direction)  $default,) {final _that = this;
switch (_that) {
case _PaginationCursor():
return $default(_that.lastId,_that.lastValue,_that.direction);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String lastId,  dynamic lastValue,  String direction)?  $default,) {final _that = this;
switch (_that) {
case _PaginationCursor() when $default != null:
return $default(_that.lastId,_that.lastValue,_that.direction);case _:
  return null;

}
}

}

/// @nodoc


class _PaginationCursor implements PaginationCursor {
  const _PaginationCursor({required this.lastId, required this.lastValue, required this.direction});
  

@override final  String lastId;
@override final  dynamic lastValue;
@override final  String direction;

/// Create a copy of PaginationCursor
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaginationCursorCopyWith<_PaginationCursor> get copyWith => __$PaginationCursorCopyWithImpl<_PaginationCursor>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaginationCursor&&(identical(other.lastId, lastId) || other.lastId == lastId)&&const DeepCollectionEquality().equals(other.lastValue, lastValue)&&(identical(other.direction, direction) || other.direction == direction));
}


@override
int get hashCode => Object.hash(runtimeType,lastId,const DeepCollectionEquality().hash(lastValue),direction);

@override
String toString() {
  return 'PaginationCursor(lastId: $lastId, lastValue: $lastValue, direction: $direction)';
}


}

/// @nodoc
abstract mixin class _$PaginationCursorCopyWith<$Res> implements $PaginationCursorCopyWith<$Res> {
  factory _$PaginationCursorCopyWith(_PaginationCursor value, $Res Function(_PaginationCursor) _then) = __$PaginationCursorCopyWithImpl;
@override @useResult
$Res call({
 String lastId, dynamic lastValue, String direction
});




}
/// @nodoc
class __$PaginationCursorCopyWithImpl<$Res>
    implements _$PaginationCursorCopyWith<$Res> {
  __$PaginationCursorCopyWithImpl(this._self, this._then);

  final _PaginationCursor _self;
  final $Res Function(_PaginationCursor) _then;

/// Create a copy of PaginationCursor
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? lastId = null,Object? lastValue = freezed,Object? direction = null,}) {
  return _then(_PaginationCursor(
lastId: null == lastId ? _self.lastId : lastId // ignore: cast_nullable_to_non_nullable
as String,lastValue: freezed == lastValue ? _self.lastValue : lastValue // ignore: cast_nullable_to_non_nullable
as dynamic,direction: null == direction ? _self.direction : direction // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$PaginatedData<T> {

 List<T> get data; int get totalCount; bool get hasNext; bool get hasPrevious; String? get nextCursor; String? get previousCursor; Map<String, dynamic> get pageInfo;
/// Create a copy of PaginatedData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaginatedDataCopyWith<T, PaginatedData<T>> get copyWith => _$PaginatedDataCopyWithImpl<T, PaginatedData<T>>(this as PaginatedData<T>, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaginatedData<T>&&const DeepCollectionEquality().equals(other.data, data)&&(identical(other.totalCount, totalCount) || other.totalCount == totalCount)&&(identical(other.hasNext, hasNext) || other.hasNext == hasNext)&&(identical(other.hasPrevious, hasPrevious) || other.hasPrevious == hasPrevious)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.previousCursor, previousCursor) || other.previousCursor == previousCursor)&&const DeepCollectionEquality().equals(other.pageInfo, pageInfo));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data),totalCount,hasNext,hasPrevious,nextCursor,previousCursor,const DeepCollectionEquality().hash(pageInfo));

@override
String toString() {
  return 'PaginatedData<$T>(data: $data, totalCount: $totalCount, hasNext: $hasNext, hasPrevious: $hasPrevious, nextCursor: $nextCursor, previousCursor: $previousCursor, pageInfo: $pageInfo)';
}


}

/// @nodoc
abstract mixin class $PaginatedDataCopyWith<T,$Res>  {
  factory $PaginatedDataCopyWith(PaginatedData<T> value, $Res Function(PaginatedData<T>) _then) = _$PaginatedDataCopyWithImpl;
@useResult
$Res call({
 List<T> data, int totalCount, bool hasNext, bool hasPrevious, String? nextCursor, String? previousCursor, Map<String, dynamic> pageInfo
});




}
/// @nodoc
class _$PaginatedDataCopyWithImpl<T,$Res>
    implements $PaginatedDataCopyWith<T, $Res> {
  _$PaginatedDataCopyWithImpl(this._self, this._then);

  final PaginatedData<T> _self;
  final $Res Function(PaginatedData<T>) _then;

/// Create a copy of PaginatedData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,Object? totalCount = null,Object? hasNext = null,Object? hasPrevious = null,Object? nextCursor = freezed,Object? previousCursor = freezed,Object? pageInfo = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<T>,totalCount: null == totalCount ? _self.totalCount : totalCount // ignore: cast_nullable_to_non_nullable
as int,hasNext: null == hasNext ? _self.hasNext : hasNext // ignore: cast_nullable_to_non_nullable
as bool,hasPrevious: null == hasPrevious ? _self.hasPrevious : hasPrevious // ignore: cast_nullable_to_non_nullable
as bool,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,previousCursor: freezed == previousCursor ? _self.previousCursor : previousCursor // ignore: cast_nullable_to_non_nullable
as String?,pageInfo: null == pageInfo ? _self.pageInfo : pageInfo // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

}


/// Adds pattern-matching-related methods to [PaginatedData].
extension PaginatedDataPatterns<T> on PaginatedData<T> {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaginatedData<T> value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaginatedData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaginatedData<T> value)  $default,){
final _that = this;
switch (_that) {
case _PaginatedData():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaginatedData<T> value)?  $default,){
final _that = this;
switch (_that) {
case _PaginatedData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<T> data,  int totalCount,  bool hasNext,  bool hasPrevious,  String? nextCursor,  String? previousCursor,  Map<String, dynamic> pageInfo)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaginatedData() when $default != null:
return $default(_that.data,_that.totalCount,_that.hasNext,_that.hasPrevious,_that.nextCursor,_that.previousCursor,_that.pageInfo);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<T> data,  int totalCount,  bool hasNext,  bool hasPrevious,  String? nextCursor,  String? previousCursor,  Map<String, dynamic> pageInfo)  $default,) {final _that = this;
switch (_that) {
case _PaginatedData():
return $default(_that.data,_that.totalCount,_that.hasNext,_that.hasPrevious,_that.nextCursor,_that.previousCursor,_that.pageInfo);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<T> data,  int totalCount,  bool hasNext,  bool hasPrevious,  String? nextCursor,  String? previousCursor,  Map<String, dynamic> pageInfo)?  $default,) {final _that = this;
switch (_that) {
case _PaginatedData() when $default != null:
return $default(_that.data,_that.totalCount,_that.hasNext,_that.hasPrevious,_that.nextCursor,_that.previousCursor,_that.pageInfo);case _:
  return null;

}
}

}

/// @nodoc


class _PaginatedData<T> extends PaginatedData<T> {
  const _PaginatedData({required final  List<T> data, required this.totalCount, required this.hasNext, required this.hasPrevious, required this.nextCursor, required this.previousCursor, required final  Map<String, dynamic> pageInfo}): _data = data,_pageInfo = pageInfo,super._();
  

 final  List<T> _data;
@override List<T> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}

@override final  int totalCount;
@override final  bool hasNext;
@override final  bool hasPrevious;
@override final  String? nextCursor;
@override final  String? previousCursor;
 final  Map<String, dynamic> _pageInfo;
@override Map<String, dynamic> get pageInfo {
  if (_pageInfo is EqualUnmodifiableMapView) return _pageInfo;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_pageInfo);
}


/// Create a copy of PaginatedData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaginatedDataCopyWith<T, _PaginatedData<T>> get copyWith => __$PaginatedDataCopyWithImpl<T, _PaginatedData<T>>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaginatedData<T>&&const DeepCollectionEquality().equals(other._data, _data)&&(identical(other.totalCount, totalCount) || other.totalCount == totalCount)&&(identical(other.hasNext, hasNext) || other.hasNext == hasNext)&&(identical(other.hasPrevious, hasPrevious) || other.hasPrevious == hasPrevious)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.previousCursor, previousCursor) || other.previousCursor == previousCursor)&&const DeepCollectionEquality().equals(other._pageInfo, _pageInfo));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data),totalCount,hasNext,hasPrevious,nextCursor,previousCursor,const DeepCollectionEquality().hash(_pageInfo));

@override
String toString() {
  return 'PaginatedData<$T>(data: $data, totalCount: $totalCount, hasNext: $hasNext, hasPrevious: $hasPrevious, nextCursor: $nextCursor, previousCursor: $previousCursor, pageInfo: $pageInfo)';
}


}

/// @nodoc
abstract mixin class _$PaginatedDataCopyWith<T,$Res> implements $PaginatedDataCopyWith<T, $Res> {
  factory _$PaginatedDataCopyWith(_PaginatedData<T> value, $Res Function(_PaginatedData<T>) _then) = __$PaginatedDataCopyWithImpl;
@override @useResult
$Res call({
 List<T> data, int totalCount, bool hasNext, bool hasPrevious, String? nextCursor, String? previousCursor, Map<String, dynamic> pageInfo
});




}
/// @nodoc
class __$PaginatedDataCopyWithImpl<T,$Res>
    implements _$PaginatedDataCopyWith<T, $Res> {
  __$PaginatedDataCopyWithImpl(this._self, this._then);

  final _PaginatedData<T> _self;
  final $Res Function(_PaginatedData<T>) _then;

/// Create a copy of PaginatedData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,Object? totalCount = null,Object? hasNext = null,Object? hasPrevious = null,Object? nextCursor = freezed,Object? previousCursor = freezed,Object? pageInfo = null,}) {
  return _then(_PaginatedData<T>(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<T>,totalCount: null == totalCount ? _self.totalCount : totalCount // ignore: cast_nullable_to_non_nullable
as int,hasNext: null == hasNext ? _self.hasNext : hasNext // ignore: cast_nullable_to_non_nullable
as bool,hasPrevious: null == hasPrevious ? _self.hasPrevious : hasPrevious // ignore: cast_nullable_to_non_nullable
as bool,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,previousCursor: freezed == previousCursor ? _self.previousCursor : previousCursor // ignore: cast_nullable_to_non_nullable
as String?,pageInfo: null == pageInfo ? _self._pageInfo : pageInfo // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}

/// @nodoc
mixin _$PaginationState<T> {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaginationState<T>);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PaginationState<$T>()';
}


}

/// @nodoc
class $PaginationStateCopyWith<T,$Res>  {
$PaginationStateCopyWith(PaginationState<T> _, $Res Function(PaginationState<T>) __);
}


/// Adds pattern-matching-related methods to [PaginationState].
extension PaginationStatePatterns<T> on PaginationState<T> {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( PaginationStateInitial<T> value)?  initial,TResult Function( PaginationStateLoadingFirstPage<T> value)?  loadingFirstPage,TResult Function( PaginationStateLoadingNextPage<T> value)?  loadingNextPage,TResult Function( PaginationStateLoaded<T> value)?  loaded,TResult Function( PaginationStateError<T> value)?  error,TResult Function( PaginationStateEmpty<T> value)?  empty,required TResult orElse(),}){
final _that = this;
switch (_that) {
case PaginationStateInitial() when initial != null:
return initial(_that);case PaginationStateLoadingFirstPage() when loadingFirstPage != null:
return loadingFirstPage(_that);case PaginationStateLoadingNextPage() when loadingNextPage != null:
return loadingNextPage(_that);case PaginationStateLoaded() when loaded != null:
return loaded(_that);case PaginationStateError() when error != null:
return error(_that);case PaginationStateEmpty() when empty != null:
return empty(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( PaginationStateInitial<T> value)  initial,required TResult Function( PaginationStateLoadingFirstPage<T> value)  loadingFirstPage,required TResult Function( PaginationStateLoadingNextPage<T> value)  loadingNextPage,required TResult Function( PaginationStateLoaded<T> value)  loaded,required TResult Function( PaginationStateError<T> value)  error,required TResult Function( PaginationStateEmpty<T> value)  empty,}){
final _that = this;
switch (_that) {
case PaginationStateInitial():
return initial(_that);case PaginationStateLoadingFirstPage():
return loadingFirstPage(_that);case PaginationStateLoadingNextPage():
return loadingNextPage(_that);case PaginationStateLoaded():
return loaded(_that);case PaginationStateError():
return error(_that);case PaginationStateEmpty():
return empty(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( PaginationStateInitial<T> value)?  initial,TResult? Function( PaginationStateLoadingFirstPage<T> value)?  loadingFirstPage,TResult? Function( PaginationStateLoadingNextPage<T> value)?  loadingNextPage,TResult? Function( PaginationStateLoaded<T> value)?  loaded,TResult? Function( PaginationStateError<T> value)?  error,TResult? Function( PaginationStateEmpty<T> value)?  empty,}){
final _that = this;
switch (_that) {
case PaginationStateInitial() when initial != null:
return initial(_that);case PaginationStateLoadingFirstPage() when loadingFirstPage != null:
return loadingFirstPage(_that);case PaginationStateLoadingNextPage() when loadingNextPage != null:
return loadingNextPage(_that);case PaginationStateLoaded() when loaded != null:
return loaded(_that);case PaginationStateError() when error != null:
return error(_that);case PaginationStateEmpty() when empty != null:
return empty(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  initial,TResult Function()?  loadingFirstPage,TResult Function( List<T> previousItems)?  loadingNextPage,TResult Function( List<T> items,  bool hasNext,  String? nextCursor,  bool isLoadingMore)?  loaded,TResult Function( String message,  List<T> previousItems)?  error,TResult Function()?  empty,required TResult orElse(),}) {final _that = this;
switch (_that) {
case PaginationStateInitial() when initial != null:
return initial();case PaginationStateLoadingFirstPage() when loadingFirstPage != null:
return loadingFirstPage();case PaginationStateLoadingNextPage() when loadingNextPage != null:
return loadingNextPage(_that.previousItems);case PaginationStateLoaded() when loaded != null:
return loaded(_that.items,_that.hasNext,_that.nextCursor,_that.isLoadingMore);case PaginationStateError() when error != null:
return error(_that.message,_that.previousItems);case PaginationStateEmpty() when empty != null:
return empty();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  initial,required TResult Function()  loadingFirstPage,required TResult Function( List<T> previousItems)  loadingNextPage,required TResult Function( List<T> items,  bool hasNext,  String? nextCursor,  bool isLoadingMore)  loaded,required TResult Function( String message,  List<T> previousItems)  error,required TResult Function()  empty,}) {final _that = this;
switch (_that) {
case PaginationStateInitial():
return initial();case PaginationStateLoadingFirstPage():
return loadingFirstPage();case PaginationStateLoadingNextPage():
return loadingNextPage(_that.previousItems);case PaginationStateLoaded():
return loaded(_that.items,_that.hasNext,_that.nextCursor,_that.isLoadingMore);case PaginationStateError():
return error(_that.message,_that.previousItems);case PaginationStateEmpty():
return empty();case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  initial,TResult? Function()?  loadingFirstPage,TResult? Function( List<T> previousItems)?  loadingNextPage,TResult? Function( List<T> items,  bool hasNext,  String? nextCursor,  bool isLoadingMore)?  loaded,TResult? Function( String message,  List<T> previousItems)?  error,TResult? Function()?  empty,}) {final _that = this;
switch (_that) {
case PaginationStateInitial() when initial != null:
return initial();case PaginationStateLoadingFirstPage() when loadingFirstPage != null:
return loadingFirstPage();case PaginationStateLoadingNextPage() when loadingNextPage != null:
return loadingNextPage(_that.previousItems);case PaginationStateLoaded() when loaded != null:
return loaded(_that.items,_that.hasNext,_that.nextCursor,_that.isLoadingMore);case PaginationStateError() when error != null:
return error(_that.message,_that.previousItems);case PaginationStateEmpty() when empty != null:
return empty();case _:
  return null;

}
}

}

/// @nodoc


class PaginationStateInitial<T> extends PaginationState<T> {
  const PaginationStateInitial(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaginationStateInitial<T>);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PaginationState<$T>.initial()';
}


}




/// @nodoc


class PaginationStateLoadingFirstPage<T> extends PaginationState<T> {
  const PaginationStateLoadingFirstPage(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaginationStateLoadingFirstPage<T>);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PaginationState<$T>.loadingFirstPage()';
}


}




/// @nodoc


class PaginationStateLoadingNextPage<T> extends PaginationState<T> {
  const PaginationStateLoadingNextPage({required final  List<T> previousItems}): _previousItems = previousItems,super._();
  

 final  List<T> _previousItems;
 List<T> get previousItems {
  if (_previousItems is EqualUnmodifiableListView) return _previousItems;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_previousItems);
}


/// Create a copy of PaginationState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaginationStateLoadingNextPageCopyWith<T, PaginationStateLoadingNextPage<T>> get copyWith => _$PaginationStateLoadingNextPageCopyWithImpl<T, PaginationStateLoadingNextPage<T>>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaginationStateLoadingNextPage<T>&&const DeepCollectionEquality().equals(other._previousItems, _previousItems));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_previousItems));

@override
String toString() {
  return 'PaginationState<$T>.loadingNextPage(previousItems: $previousItems)';
}


}

/// @nodoc
abstract mixin class $PaginationStateLoadingNextPageCopyWith<T,$Res> implements $PaginationStateCopyWith<T, $Res> {
  factory $PaginationStateLoadingNextPageCopyWith(PaginationStateLoadingNextPage<T> value, $Res Function(PaginationStateLoadingNextPage<T>) _then) = _$PaginationStateLoadingNextPageCopyWithImpl;
@useResult
$Res call({
 List<T> previousItems
});




}
/// @nodoc
class _$PaginationStateLoadingNextPageCopyWithImpl<T,$Res>
    implements $PaginationStateLoadingNextPageCopyWith<T, $Res> {
  _$PaginationStateLoadingNextPageCopyWithImpl(this._self, this._then);

  final PaginationStateLoadingNextPage<T> _self;
  final $Res Function(PaginationStateLoadingNextPage<T>) _then;

/// Create a copy of PaginationState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? previousItems = null,}) {
  return _then(PaginationStateLoadingNextPage<T>(
previousItems: null == previousItems ? _self._previousItems : previousItems // ignore: cast_nullable_to_non_nullable
as List<T>,
  ));
}


}

/// @nodoc


class PaginationStateLoaded<T> extends PaginationState<T> {
  const PaginationStateLoaded({required final  List<T> items, required this.hasNext, required this.nextCursor, required this.isLoadingMore}): _items = items,super._();
  

 final  List<T> _items;
 List<T> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

 final  bool hasNext;
 final  String? nextCursor;
 final  bool isLoadingMore;

/// Create a copy of PaginationState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaginationStateLoadedCopyWith<T, PaginationStateLoaded<T>> get copyWith => _$PaginationStateLoadedCopyWithImpl<T, PaginationStateLoaded<T>>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaginationStateLoaded<T>&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.hasNext, hasNext) || other.hasNext == hasNext)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.isLoadingMore, isLoadingMore) || other.isLoadingMore == isLoadingMore));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_items),hasNext,nextCursor,isLoadingMore);

@override
String toString() {
  return 'PaginationState<$T>.loaded(items: $items, hasNext: $hasNext, nextCursor: $nextCursor, isLoadingMore: $isLoadingMore)';
}


}

/// @nodoc
abstract mixin class $PaginationStateLoadedCopyWith<T,$Res> implements $PaginationStateCopyWith<T, $Res> {
  factory $PaginationStateLoadedCopyWith(PaginationStateLoaded<T> value, $Res Function(PaginationStateLoaded<T>) _then) = _$PaginationStateLoadedCopyWithImpl;
@useResult
$Res call({
 List<T> items, bool hasNext, String? nextCursor, bool isLoadingMore
});




}
/// @nodoc
class _$PaginationStateLoadedCopyWithImpl<T,$Res>
    implements $PaginationStateLoadedCopyWith<T, $Res> {
  _$PaginationStateLoadedCopyWithImpl(this._self, this._then);

  final PaginationStateLoaded<T> _self;
  final $Res Function(PaginationStateLoaded<T>) _then;

/// Create a copy of PaginationState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? items = null,Object? hasNext = null,Object? nextCursor = freezed,Object? isLoadingMore = null,}) {
  return _then(PaginationStateLoaded<T>(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<T>,hasNext: null == hasNext ? _self.hasNext : hasNext // ignore: cast_nullable_to_non_nullable
as bool,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,isLoadingMore: null == isLoadingMore ? _self.isLoadingMore : isLoadingMore // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class PaginationStateError<T> extends PaginationState<T> {
  const PaginationStateError({required this.message, required final  List<T> previousItems}): _previousItems = previousItems,super._();
  

 final  String message;
 final  List<T> _previousItems;
 List<T> get previousItems {
  if (_previousItems is EqualUnmodifiableListView) return _previousItems;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_previousItems);
}


/// Create a copy of PaginationState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaginationStateErrorCopyWith<T, PaginationStateError<T>> get copyWith => _$PaginationStateErrorCopyWithImpl<T, PaginationStateError<T>>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaginationStateError<T>&&(identical(other.message, message) || other.message == message)&&const DeepCollectionEquality().equals(other._previousItems, _previousItems));
}


@override
int get hashCode => Object.hash(runtimeType,message,const DeepCollectionEquality().hash(_previousItems));

@override
String toString() {
  return 'PaginationState<$T>.error(message: $message, previousItems: $previousItems)';
}


}

/// @nodoc
abstract mixin class $PaginationStateErrorCopyWith<T,$Res> implements $PaginationStateCopyWith<T, $Res> {
  factory $PaginationStateErrorCopyWith(PaginationStateError<T> value, $Res Function(PaginationStateError<T>) _then) = _$PaginationStateErrorCopyWithImpl;
@useResult
$Res call({
 String message, List<T> previousItems
});




}
/// @nodoc
class _$PaginationStateErrorCopyWithImpl<T,$Res>
    implements $PaginationStateErrorCopyWith<T, $Res> {
  _$PaginationStateErrorCopyWithImpl(this._self, this._then);

  final PaginationStateError<T> _self;
  final $Res Function(PaginationStateError<T>) _then;

/// Create a copy of PaginationState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,Object? previousItems = null,}) {
  return _then(PaginationStateError<T>(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,previousItems: null == previousItems ? _self._previousItems : previousItems // ignore: cast_nullable_to_non_nullable
as List<T>,
  ));
}


}

/// @nodoc


class PaginationStateEmpty<T> extends PaginationState<T> {
  const PaginationStateEmpty(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaginationStateEmpty<T>);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PaginationState<$T>.empty()';
}


}




/// @nodoc
mixin _$PaginationConfig {

 int get pageSize; String get sortBy; String get sortDirection; String? get searchQuery; Map<String, dynamic> get filters;
/// Create a copy of PaginationConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaginationConfigCopyWith<PaginationConfig> get copyWith => _$PaginationConfigCopyWithImpl<PaginationConfig>(this as PaginationConfig, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaginationConfig&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize)&&(identical(other.sortBy, sortBy) || other.sortBy == sortBy)&&(identical(other.sortDirection, sortDirection) || other.sortDirection == sortDirection)&&(identical(other.searchQuery, searchQuery) || other.searchQuery == searchQuery)&&const DeepCollectionEquality().equals(other.filters, filters));
}


@override
int get hashCode => Object.hash(runtimeType,pageSize,sortBy,sortDirection,searchQuery,const DeepCollectionEquality().hash(filters));

@override
String toString() {
  return 'PaginationConfig(pageSize: $pageSize, sortBy: $sortBy, sortDirection: $sortDirection, searchQuery: $searchQuery, filters: $filters)';
}


}

/// @nodoc
abstract mixin class $PaginationConfigCopyWith<$Res>  {
  factory $PaginationConfigCopyWith(PaginationConfig value, $Res Function(PaginationConfig) _then) = _$PaginationConfigCopyWithImpl;
@useResult
$Res call({
 int pageSize, String sortBy, String sortDirection, String? searchQuery, Map<String, dynamic> filters
});




}
/// @nodoc
class _$PaginationConfigCopyWithImpl<$Res>
    implements $PaginationConfigCopyWith<$Res> {
  _$PaginationConfigCopyWithImpl(this._self, this._then);

  final PaginationConfig _self;
  final $Res Function(PaginationConfig) _then;

/// Create a copy of PaginationConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pageSize = null,Object? sortBy = null,Object? sortDirection = null,Object? searchQuery = freezed,Object? filters = null,}) {
  return _then(_self.copyWith(
pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,sortBy: null == sortBy ? _self.sortBy : sortBy // ignore: cast_nullable_to_non_nullable
as String,sortDirection: null == sortDirection ? _self.sortDirection : sortDirection // ignore: cast_nullable_to_non_nullable
as String,searchQuery: freezed == searchQuery ? _self.searchQuery : searchQuery // ignore: cast_nullable_to_non_nullable
as String?,filters: null == filters ? _self.filters : filters // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

}


/// Adds pattern-matching-related methods to [PaginationConfig].
extension PaginationConfigPatterns on PaginationConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaginationConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaginationConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaginationConfig value)  $default,){
final _that = this;
switch (_that) {
case _PaginationConfig():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaginationConfig value)?  $default,){
final _that = this;
switch (_that) {
case _PaginationConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int pageSize,  String sortBy,  String sortDirection,  String? searchQuery,  Map<String, dynamic> filters)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaginationConfig() when $default != null:
return $default(_that.pageSize,_that.sortBy,_that.sortDirection,_that.searchQuery,_that.filters);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int pageSize,  String sortBy,  String sortDirection,  String? searchQuery,  Map<String, dynamic> filters)  $default,) {final _that = this;
switch (_that) {
case _PaginationConfig():
return $default(_that.pageSize,_that.sortBy,_that.sortDirection,_that.searchQuery,_that.filters);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int pageSize,  String sortBy,  String sortDirection,  String? searchQuery,  Map<String, dynamic> filters)?  $default,) {final _that = this;
switch (_that) {
case _PaginationConfig() when $default != null:
return $default(_that.pageSize,_that.sortBy,_that.sortDirection,_that.searchQuery,_that.filters);case _:
  return null;

}
}

}

/// @nodoc


class _PaginationConfig extends PaginationConfig {
  const _PaginationConfig({required this.pageSize, required this.sortBy, required this.sortDirection, required this.searchQuery, required final  Map<String, dynamic> filters}): _filters = filters,super._();
  

@override final  int pageSize;
@override final  String sortBy;
@override final  String sortDirection;
@override final  String? searchQuery;
 final  Map<String, dynamic> _filters;
@override Map<String, dynamic> get filters {
  if (_filters is EqualUnmodifiableMapView) return _filters;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_filters);
}


/// Create a copy of PaginationConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaginationConfigCopyWith<_PaginationConfig> get copyWith => __$PaginationConfigCopyWithImpl<_PaginationConfig>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaginationConfig&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize)&&(identical(other.sortBy, sortBy) || other.sortBy == sortBy)&&(identical(other.sortDirection, sortDirection) || other.sortDirection == sortDirection)&&(identical(other.searchQuery, searchQuery) || other.searchQuery == searchQuery)&&const DeepCollectionEquality().equals(other._filters, _filters));
}


@override
int get hashCode => Object.hash(runtimeType,pageSize,sortBy,sortDirection,searchQuery,const DeepCollectionEquality().hash(_filters));

@override
String toString() {
  return 'PaginationConfig(pageSize: $pageSize, sortBy: $sortBy, sortDirection: $sortDirection, searchQuery: $searchQuery, filters: $filters)';
}


}

/// @nodoc
abstract mixin class _$PaginationConfigCopyWith<$Res> implements $PaginationConfigCopyWith<$Res> {
  factory _$PaginationConfigCopyWith(_PaginationConfig value, $Res Function(_PaginationConfig) _then) = __$PaginationConfigCopyWithImpl;
@override @useResult
$Res call({
 int pageSize, String sortBy, String sortDirection, String? searchQuery, Map<String, dynamic> filters
});




}
/// @nodoc
class __$PaginationConfigCopyWithImpl<$Res>
    implements _$PaginationConfigCopyWith<$Res> {
  __$PaginationConfigCopyWithImpl(this._self, this._then);

  final _PaginationConfig _self;
  final $Res Function(_PaginationConfig) _then;

/// Create a copy of PaginationConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pageSize = null,Object? sortBy = null,Object? sortDirection = null,Object? searchQuery = freezed,Object? filters = null,}) {
  return _then(_PaginationConfig(
pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,sortBy: null == sortBy ? _self.sortBy : sortBy // ignore: cast_nullable_to_non_nullable
as String,sortDirection: null == sortDirection ? _self.sortDirection : sortDirection // ignore: cast_nullable_to_non_nullable
as String,searchQuery: freezed == searchQuery ? _self.searchQuery : searchQuery // ignore: cast_nullable_to_non_nullable
as String?,filters: null == filters ? _self._filters : filters // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}

/// @nodoc
mixin _$PaginationStats {

 int get totalItemsLoaded; int get pageCount; Duration get loadTime; String get lastLoadedAt;
/// Create a copy of PaginationStats
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaginationStatsCopyWith<PaginationStats> get copyWith => _$PaginationStatsCopyWithImpl<PaginationStats>(this as PaginationStats, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaginationStats&&(identical(other.totalItemsLoaded, totalItemsLoaded) || other.totalItemsLoaded == totalItemsLoaded)&&(identical(other.pageCount, pageCount) || other.pageCount == pageCount)&&(identical(other.loadTime, loadTime) || other.loadTime == loadTime)&&(identical(other.lastLoadedAt, lastLoadedAt) || other.lastLoadedAt == lastLoadedAt));
}


@override
int get hashCode => Object.hash(runtimeType,totalItemsLoaded,pageCount,loadTime,lastLoadedAt);

@override
String toString() {
  return 'PaginationStats(totalItemsLoaded: $totalItemsLoaded, pageCount: $pageCount, loadTime: $loadTime, lastLoadedAt: $lastLoadedAt)';
}


}

/// @nodoc
abstract mixin class $PaginationStatsCopyWith<$Res>  {
  factory $PaginationStatsCopyWith(PaginationStats value, $Res Function(PaginationStats) _then) = _$PaginationStatsCopyWithImpl;
@useResult
$Res call({
 int totalItemsLoaded, int pageCount, Duration loadTime, String lastLoadedAt
});




}
/// @nodoc
class _$PaginationStatsCopyWithImpl<$Res>
    implements $PaginationStatsCopyWith<$Res> {
  _$PaginationStatsCopyWithImpl(this._self, this._then);

  final PaginationStats _self;
  final $Res Function(PaginationStats) _then;

/// Create a copy of PaginationStats
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? totalItemsLoaded = null,Object? pageCount = null,Object? loadTime = null,Object? lastLoadedAt = null,}) {
  return _then(_self.copyWith(
totalItemsLoaded: null == totalItemsLoaded ? _self.totalItemsLoaded : totalItemsLoaded // ignore: cast_nullable_to_non_nullable
as int,pageCount: null == pageCount ? _self.pageCount : pageCount // ignore: cast_nullable_to_non_nullable
as int,loadTime: null == loadTime ? _self.loadTime : loadTime // ignore: cast_nullable_to_non_nullable
as Duration,lastLoadedAt: null == lastLoadedAt ? _self.lastLoadedAt : lastLoadedAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PaginationStats].
extension PaginationStatsPatterns on PaginationStats {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaginationStats value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaginationStats() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaginationStats value)  $default,){
final _that = this;
switch (_that) {
case _PaginationStats():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaginationStats value)?  $default,){
final _that = this;
switch (_that) {
case _PaginationStats() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int totalItemsLoaded,  int pageCount,  Duration loadTime,  String lastLoadedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaginationStats() when $default != null:
return $default(_that.totalItemsLoaded,_that.pageCount,_that.loadTime,_that.lastLoadedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int totalItemsLoaded,  int pageCount,  Duration loadTime,  String lastLoadedAt)  $default,) {final _that = this;
switch (_that) {
case _PaginationStats():
return $default(_that.totalItemsLoaded,_that.pageCount,_that.loadTime,_that.lastLoadedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int totalItemsLoaded,  int pageCount,  Duration loadTime,  String lastLoadedAt)?  $default,) {final _that = this;
switch (_that) {
case _PaginationStats() when $default != null:
return $default(_that.totalItemsLoaded,_that.pageCount,_that.loadTime,_that.lastLoadedAt);case _:
  return null;

}
}

}

/// @nodoc


class _PaginationStats implements PaginationStats {
  const _PaginationStats({required this.totalItemsLoaded, required this.pageCount, required this.loadTime, required this.lastLoadedAt});
  

@override final  int totalItemsLoaded;
@override final  int pageCount;
@override final  Duration loadTime;
@override final  String lastLoadedAt;

/// Create a copy of PaginationStats
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaginationStatsCopyWith<_PaginationStats> get copyWith => __$PaginationStatsCopyWithImpl<_PaginationStats>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaginationStats&&(identical(other.totalItemsLoaded, totalItemsLoaded) || other.totalItemsLoaded == totalItemsLoaded)&&(identical(other.pageCount, pageCount) || other.pageCount == pageCount)&&(identical(other.loadTime, loadTime) || other.loadTime == loadTime)&&(identical(other.lastLoadedAt, lastLoadedAt) || other.lastLoadedAt == lastLoadedAt));
}


@override
int get hashCode => Object.hash(runtimeType,totalItemsLoaded,pageCount,loadTime,lastLoadedAt);

@override
String toString() {
  return 'PaginationStats(totalItemsLoaded: $totalItemsLoaded, pageCount: $pageCount, loadTime: $loadTime, lastLoadedAt: $lastLoadedAt)';
}


}

/// @nodoc
abstract mixin class _$PaginationStatsCopyWith<$Res> implements $PaginationStatsCopyWith<$Res> {
  factory _$PaginationStatsCopyWith(_PaginationStats value, $Res Function(_PaginationStats) _then) = __$PaginationStatsCopyWithImpl;
@override @useResult
$Res call({
 int totalItemsLoaded, int pageCount, Duration loadTime, String lastLoadedAt
});




}
/// @nodoc
class __$PaginationStatsCopyWithImpl<$Res>
    implements _$PaginationStatsCopyWith<$Res> {
  __$PaginationStatsCopyWithImpl(this._self, this._then);

  final _PaginationStats _self;
  final $Res Function(_PaginationStats) _then;

/// Create a copy of PaginationStats
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? totalItemsLoaded = null,Object? pageCount = null,Object? loadTime = null,Object? lastLoadedAt = null,}) {
  return _then(_PaginationStats(
totalItemsLoaded: null == totalItemsLoaded ? _self.totalItemsLoaded : totalItemsLoaded // ignore: cast_nullable_to_non_nullable
as int,pageCount: null == pageCount ? _self.pageCount : pageCount // ignore: cast_nullable_to_non_nullable
as int,loadTime: null == loadTime ? _self.loadTime : loadTime // ignore: cast_nullable_to_non_nullable
as Duration,lastLoadedAt: null == lastLoadedAt ? _self.lastLoadedAt : lastLoadedAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
