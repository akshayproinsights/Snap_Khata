import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile/shared/widgets/app_toast.dart';

class WhatsAppHelper {
  static Future<void> launchWhatsApp(BuildContext context, String message,
      {String? phone}) async {
    final baseUrl =
        phone != null ? 'whatsapp://send?phone=$phone' : 'whatsapp://send';
    final url =
        '$baseUrl${phone != null ? '&' : '?'}text=${Uri.encodeComponent(message)}';

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Fallback to web if app is not installed
      final webUrl =
          'https://wa.me/${phone ?? ''}?text=${Uri.encodeComponent(message)}';
      final webUri = Uri.parse(webUrl);
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          AppToast.showError(context, 'Could not launch WhatsApp');
        }
      }
    }
  }
}
