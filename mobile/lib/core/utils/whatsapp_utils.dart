import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

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
      final filteredExtraFields = extraFields.entries.where((e) {
        final key = e.key.toLowerCase();
        return !key.contains('created at') && 
               !key.contains('total bill amount') && 
               !key.contains('mobile number');
      });
      if (filteredExtraFields.isNotEmpty) {
        final extraStr = filteredExtraFields.map((e) => '🏷️ *${e.key}:* ${e.value}').join('\n');
        extraTexts = '\n\n$extraStr';
      }
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

  /// Helper to share a receipt visually with options for Digital Receipt vs Receipt Photo.
  /// This presents a dialog for the user to select the sharing mode and enter/confirm the phone number.
  static Future<String?> shareReceiptWithOptions(
    BuildContext context, {
    required String phone,
    required String shareUrl,
    String? imageUrl,
    required String caption,
    required String shopName,
  }) async {
    final phoneController = TextEditingController(text: phone);
    bool shareOriginalImage = false;

    if (!context.mounted) return null;

    final shareResult = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          void executeShare(String phoneToUse) async {
            final message =
                '$caption\n\nView details:\n$shareUrl\n\nThank you!\n— *${shopName.trim()}*';

            if (shareOriginalImage &&
                imageUrl != null &&
                imageUrl.isNotEmpty &&
                imageUrl != 'null') {
              await shareActualImageOnWhatsApp(
                context: ctx,
                imageUrl: imageUrl,
                phone: phoneToUse,
                caption: message,
              );
            } else {
              await openWhatsAppChat(phone: phoneToUse, message: message);
            }
            if (ctx.mounted) Navigator.pop(ctx, phoneToUse);
          }

          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              left: 24,
              right: 24,
              top: 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const FaIcon(FontAwesomeIcons.whatsapp,
                          size: 20, color: Color(0xFF25D366)),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Share on WhatsApp',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Choose Receipt Mode',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildModeButton(
                          label: 'Digital Receipt',
                          icon: LucideIcons.receipt,
                          isSelected: !shareOriginalImage,
                          onTap: () => setState(() => shareOriginalImage = false),
                        ),
                      ),
                      Expanded(
                        child: _buildModeButton(
                          label: 'Receipt Photo',
                          icon: LucideIcons.image,
                          isSelected: shareOriginalImage,
                          onTap: () => setState(() => shareOriginalImage = true),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Customer Mobile Number',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  autofocus: phone.isEmpty,
                  decoration: InputDecoration(
                    prefixText: '+91 ',
                    hintText: 'Enter 10-digit number',
                    filled: true,
                    fillColor: Colors.grey.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => executeShare(''),
                        child: const Text('Skip Number',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => executeShare(phoneController.text.trim()),
                        child: const Text('Send on WhatsApp',
                            style: TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return shareResult;
  }

  static Widget _buildModeButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 20, color: isSelected ? const Color(0xFF25D366) : Colors.grey),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.black : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a short, SMB-friendly WhatsApp reminder message for a party/ledger.
  ///
  /// In [useReceiptPhoto] mode the link is the direct image URL of the receipt.
  /// Otherwise it is the account-statement web link.
  static String buildPartyReminderMessage({
    required String customerName,
    required String shopName,
    required double totalBilled,
    required double totalPaid,
    required double balanceDue,
    required String statementLink,
    String? upiId,
    bool useReceiptPhoto = false,
    String? receiptPhotoUrl,
    String? receiptNumber,
  }) {
    final firstName = customerName.trim().split(' ').first;
    final shop = shopName.trim();

    if (useReceiptPhoto &&
        receiptPhotoUrl != null &&
        receiptPhotoUrl.isNotEmpty &&
        receiptPhotoUrl != 'null') {
      final invoiceRef =
          receiptNumber != null ? ' (Bill #$receiptNumber)' : '';
      return 'Hi $firstName,\n\n'
          '🙏 Friendly reminder from *$shop*\n\n'
          '⚠️ *Amount Due: ${formatIndianCurrency(balanceDue)}*\n\n'
          'Your receipt$invoiceRef is here 👇\n'
          '$receiptPhotoUrl\n\n'
          'Please clear the balance at your earliest convenience.\n\n'
          'Thank you! 🙏\n'
          '— *$shop*';
    }

    // Account Statement mode
    String msg = 'Hi $firstName,\n\n'
        '🙏 A friendly reminder from *$shop*\n\n'
        '📋 Total Bill: ${formatIndianCurrency(totalBilled)}\n'
        '✅ Amount Paid: ${formatIndianCurrency(totalPaid)}\n'
        '⚠️ *Balance Due: ${formatIndianCurrency(balanceDue)}*\n\n'
        'View your full account here:\n'
        '$statementLink\n';

    if (upiId != null && upiId.isNotEmpty) {
      msg += '\n💳 Pay via UPI: $upiId\n';
    }

    msg += '\nThank you for your business! 🙏\n— *$shop*';
    return msg;
  }

  /// Downloads an image and shares it natively via the system share sheet.
  ///
  /// On Flutter Web/PWA: fetches image as raw bytes and uses [XFile.fromData]
  /// which triggers the Web Share API with files — the ONLY approach that works
  /// on a mobile browser/PWA (file paths & getTemporaryDirectory don't exist on web).
  ///
  /// On native (Android/iOS): falls back to downloading to a temp file path.
  static Future<void> shareActualImageOnWhatsApp({
    required BuildContext context,
    required String imageUrl,
    required String caption,
    String? phone,
  }) async {
    try {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⏳ Preparing image for sharing...')),
        );
      }

      final dio = Dio();

      if (kIsWeb) {
        // ── WEB / PWA PATH ─────────────────────────────────────────────────
        // Must use in-memory bytes + XFile.fromData to trigger the
        // Web Share API with a real file. Using a file path on web
        // silently fails — this was the production bug.
        final response = await dio.get<List<int>>(
          imageUrl,
          options: Options(responseType: ResponseType.bytes),
        );

        final bytes = Uint8List.fromList(response.data!);
        final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';

        await SharePlus.instance.share(
          ShareParams(
            files: [XFile.fromData(bytes, mimeType: 'image/jpeg', name: fileName)],
            text: caption,
          ),
        );
      } else {
        // ── NATIVE (Android / iOS) PATH ────────────────────────────────────
        final tempDir = await getTemporaryDirectory();
        final tempFilePath = '${tempDir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';

        await dio.download(imageUrl, tempFilePath);

        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(tempFilePath, mimeType: 'image/jpeg')],
            text: caption,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error sharing image: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e. Sending link instead.')),
        );
        // Graceful fallback: open WhatsApp with text message containing the URL
        if (phone != null && phone.isNotEmpty) {
          await openWhatsAppChat(phone: phone, message: '$caption\n\n$imageUrl');
        }
      }
    }
  }
}
