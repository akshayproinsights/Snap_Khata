// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CustomerActivity _$CustomerActivityFromJson(Map<String, dynamic> json) =>
    _CustomerActivity(
      id: json['id'] as String,
      entityName: json['entityName'] as String,
      transactionDate: DateTime.parse(json['transactionDate'] as String),
      amount: (json['amount'] as num).toDouble(),
      displayId: json['displayId'] as String?,
      transactionType: json['transactionType'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$CustomerActivityToJson(_CustomerActivity instance) =>
    <String, dynamic>{
      'id': instance.id,
      'entityName': instance.entityName,
      'transactionDate': instance.transactionDate.toIso8601String(),
      'amount': instance.amount,
      'displayId': instance.displayId,
      'transactionType': instance.transactionType,
      'runtimeType': instance.$type,
    };

_VendorActivity _$VendorActivityFromJson(Map<String, dynamic> json) =>
    _VendorActivity(
      id: json['id'] as String,
      entityName: json['entityName'] as String,
      transactionDate: DateTime.parse(json['transactionDate'] as String),
      amount: (json['amount'] as num).toDouble(),
      displayId: json['displayId'] as String?,
      isPaid: json['isPaid'] as bool,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$VendorActivityToJson(_VendorActivity instance) =>
    <String, dynamic>{
      'id': instance.id,
      'entityName': instance.entityName,
      'transactionDate': instance.transactionDate.toIso8601String(),
      'amount': instance.amount,
      'displayId': instance.displayId,
      'isPaid': instance.isPaid,
      'runtimeType': instance.$type,
    };
