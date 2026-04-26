import 'package:mobile/core/network/api_client.dart';

class ReceiptShareLinkUtils {
  static Future<String?> buildSignedOrLegacyLink({
    required String receiptNumber,
    String? username,
    String? gstMode,
  }) async {
    final normalizedGst = (gstMode != null && gstMode.isNotEmpty && gstMode != 'none')
        ? gstMode
        : null;

    try {
      final response = await ApiClient()
          .dio
          .post('/api/public/receipts/$receiptNumber/share-token');
      final data = response.data;
      if (data is! Map) return null;

      final shareUrl = data['share_url']?.toString();
      if (shareUrl == null || shareUrl.isEmpty) return null;
      if (normalizedGst == null) return shareUrl;

      final parsed = Uri.parse(shareUrl);
      final mergedQuery = Map<String, String>.from(parsed.queryParameters);
      mergedQuery['g'] = normalizedGst;
      return parsed.replace(queryParameters: mergedQuery).toString();
    } catch (_) {
      return null;
    }
  }
}
