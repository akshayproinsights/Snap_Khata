import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

enum OrderPaymentStatus { fullyPaid, partiallyPaid, unpaid }

class WhatsAppUtils {
  WhatsAppUtils._();

  /// Formats double amount into Indian Rupee format (e.g., ₹1,25,000)
  static String formatIndianCurrency(double amount) {
    String val = amount.toStringAsFixed(0);
    if (val.length <= 3) return '₹$val';

    String lastThree = val.substring(val.length - 3);
    String remaining = val.substring(0, val.length - 3);

    String result = '';
    String rem = remaining;
    while (rem.length > 2) {
      result = ',${rem.substring(rem.length - 2)}$result';
      rem = rem.substring(0, rem.length - 2);
    }
    result = rem + result;

    return '₹$result,$lastThree';
  }

  static String getWhatsAppCaption({
    required OrderPaymentStatus status,
    required String customerName,
    required String businessName,
    required String orderNumber,
    required double totalAmount,
    double? paidAmount,
    double? pendingAmount,
    String? upiDeepLink,
    Map<String, String>? extraFields,
  }) {
    final totalFmt = formatIndianCurrency(totalAmount);
    final paidFmt = paidAmount != null ? formatIndianCurrency(paidAmount) : '';
    final pendingFmt = pendingAmount != null ? formatIndianCurrency(pendingAmount) : '';
    
    String extraTexts = '';
    if (extraFields != null && extraFields.isNotEmpty) {
      final extraStr = extraFields.entries.map((e) => '🏷️ *${e.key}:* ${e.value}').join('\n');
      extraTexts = '\n\n$extraStr';
    }

    switch (status) {
      case OrderPaymentStatus.unpaid:
        return 'Hi $customerName,\n'
            'Your order from *${businessName.trim()}* is ready. 📝\n\n'
            '⚠️ *Amount Due: $totalFmt*$extraTexts\n\n'
            'Thank you for choosing *${businessName.trim()}*.';

      case OrderPaymentStatus.partiallyPaid:
        return 'Hi $customerName,\n'
            'Your order with *${businessName.trim()}* has been successfully generated. 📝\n\n'
            'Here is your payment summary:\n'
            '🛒 Total Bill: $totalFmt\n'
            '✅ Amount Paid: $paidFmt\n'
            '⏳ Pending Due: $pendingFmt$extraTexts';

      case OrderPaymentStatus.fullyPaid:
        return 'Hi $customerName,\n'
            'Your order with *${businessName.trim()}* has been successfully generated. 📝\n\n'
            '💳 Amount Paid: $totalFmt$extraTexts';
    }
  }

  /// Normalizes an Indian mobile number to `91XXXXXXXXXX` (digits only).
  static String normalizeIndianPhone(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.startsWith('91')) return digitsOnly;
    return '91$digitsOnly';
  }

  /// Builds a wa.me deep link for the given phone and message.
  ///
  /// Example: https://wa.me/91XXXXXXXXXX?text=`url_encoded_message`
  static Uri buildWaMeUri({
    String? phone,
    required String message,
  }) {
    final encodedMessage = Uri.encodeComponent(message);
    if (phone == null || phone.trim().isEmpty) {
      // Use https://wa.me/ consistently as it's a valid universal link for web/PWA
      return Uri.parse('https://wa.me/?text=$encodedMessage');
    }
    final normalized = normalizeIndianPhone(phone);
    return Uri.parse('https://wa.me/$normalized?text=$encodedMessage');
  }

  /// Opens WhatsApp using the wa.me deep link in an external application mode.
  ///
  /// Returns `true` if the native WhatsApp app (or browser) could be opened.
  static Future<bool> openWhatsAppChat({
    String? phone,
    required String message,
  }) async {
    final uri = buildWaMeUri(phone: phone, message: message);
    
    // For universal links (https://wa.me), LaunchMode.platformDefault is often 
    // more reliable on iOS PWA as it allows the system to handle the handoff.
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
    }
    
    // Fallback if the primary uri fails, and we didn't specify a phone
    if (phone == null || phone.trim().isEmpty) {
      final webUri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
      try {
        if (await canLaunchUrl(webUri)) {
          return await launchUrl(webUri, mode: LaunchMode.platformDefault);
        }
      } catch (_) {}
    }
    return false;
  }
  
  /// Helper to share a receipt visually, asking for a phone number only if missing.
  /// If missing, it provides options to skip (opening WhatsApp without a number).
  static Future<void> shareReceipt(
    BuildContext context, {
    required String phone,
    required String message,
    String dialogTitle = 'Share Receipt',
    String dialogContent = 'Enter customer\'s mobile number, or skip to select contact directly in WhatsApp.',
  }) async {
    String finalPhone = phone;

    if (finalPhone.trim().isEmpty) {
      final phoneController = TextEditingController();
      if (!context.mounted) return;

      await showDialog<String?>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(dialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dialogContent,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Customer Phone Number',
                  prefixText: '+91 ',
                  hintText: 'e.g. 9876543210',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Cancelled entirely
              child: const Text('Cancel'),
            ),
            FilledButton.tonal(
              onPressed: () async {
                // Launch WhatsApp IMMEDIATELY inside the handler to preserve user gesture on iOS
                await openWhatsAppChat(phone: '', message: message);
                if (context.mounted) Navigator.pop(context, ''); 
              },
              child: const Text('Skip'),
            ),
            FilledButton(
              onPressed: () async {
                final enteredPhone = phoneController.text.trim();
                // Launch WhatsApp IMMEDIATELY inside the handler to preserve user gesture on iOS
                await openWhatsAppChat(phone: enteredPhone, message: message);
                if (context.mounted) Navigator.pop(context, enteredPhone);
              },
              child: const Text('Share'),
            ),
          ],
        ),
      );

      // If result is null, user cancelled. If not null, we already launched WhatsApp.
      return;
    }

    if (!context.mounted) return;
    
    final opened = await openWhatsAppChat(
      phone: finalPhone,
      message: message,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not open WhatsApp. Please ensure it is installed.')),
      );
    }
  }
}
