import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/verified/domain/models/verified_models.dart';

class VerifiedRepository {
  final Dio _dio;

  VerifiedRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  Future<List<VerifiedInvoice>> getVerifiedInvoices({
    String? search,
    String? dateFrom,
    String? dateTo,
    String? receiptNumber,
    String? customerName,
    String? description,
  }) async {
    final queryParams = <String, dynamic>{};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (dateFrom != null && dateFrom.isNotEmpty) {
      queryParams['date_from'] = dateFrom;
    }
    if (dateTo != null && dateTo.isNotEmpty) queryParams['date_to'] = dateTo;
    if (receiptNumber != null && receiptNumber.isNotEmpty) {
      queryParams['receipt_number'] = receiptNumber;
    }
    if (customerName != null && customerName.isNotEmpty) {
      queryParams['customer_name'] = customerName;
    }
    if (description != null && description.isNotEmpty) {
      queryParams['description'] = description;
    }

    final response =
        await _dio.get('/api/verified/', queryParameters: queryParams);
    final records = response.data['records'] as List?;
    return (records ?? [])
        .map((json) => VerifiedInvoice.fromJson(json))
        .toList();
  }

  Future<void> updateVerifiedInvoice(VerifiedInvoice record) async {
    await _dio.put('/api/verified/update', data: record.toJson());
  }

  Future<void> deleteBulk(List<String> rowIds) async {
    await _dio.post('/api/verified/delete-bulk', data: {
      'row_ids': rowIds,
    });
  }

  Future<void> save(List<VerifiedInvoice> records) async {
    await _dio.post('/api/verified/save', data: {
      'records': records.map((e) => e.toJson()).toList(),
    });
  }

  Future<dynamic> exportToExcel(Map<String, dynamic> filters) async {
    final response = await _dio.get('/api/verified/export',
        queryParameters: {...filters, 'format': 'excel'},
        options: Options(responseType: ResponseType.bytes));
    return response.data;
  }
}
