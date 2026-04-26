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
      balanceDue: (json['balanceDue'] as num?)?.toDouble(),
      receiptLink: json['receiptLink'] as String? ?? '',
      invoiceDate: json['invoiceDate'] as String? ?? '',
      mobileNumber: json['mobileNumber'] as String? ?? '',
      paymentMode: json['paymentMode'] as String? ?? 'Cash',
      invoiceBalanceDue: (json['invoiceBalanceDue'] as num?)?.toDouble() ?? 0.0,
      receivedAmount: (json['receivedAmount'] as num?)?.toDouble() ?? 0.0,
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          const [],
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
      'balanceDue': instance.balanceDue,
      'receiptLink': instance.receiptLink,
      'invoiceDate': instance.invoiceDate,
      'mobileNumber': instance.mobileNumber,
      'paymentMode': instance.paymentMode,
      'invoiceBalanceDue': instance.invoiceBalanceDue,
      'receivedAmount': instance.receivedAmount,
      'items': instance.items,
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
      balanceDue: (json['balanceDue'] as num?)?.toDouble(),
      totalPriceHike: (json['totalPriceHike'] as num?)?.toDouble() ?? 0.0,
      receiptLink: json['receiptLink'] as String? ?? '',
      invoiceDate: json['invoiceDate'] as String? ?? '',
      inventoryItems:
          (json['inventoryItems'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          const [],
      isVerified: json['isVerified'] as bool? ?? false,
      balanceOwed: (json['balanceOwed'] as num?)?.toDouble() ?? 0.0,
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
      'balanceDue': instance.balanceDue,
      'totalPriceHike': instance.totalPriceHike,
      'receiptLink': instance.receiptLink,
      'invoiceDate': instance.invoiceDate,
      'inventoryItems': instance.inventoryItems,
      'isVerified': instance.isVerified,
      'balanceOwed': instance.balanceOwed,
      'runtimeType': instance.$type,
    };
