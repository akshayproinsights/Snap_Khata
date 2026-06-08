import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'js_interop_stub.dart' if (dart.library.js_interop) 'js_interop_web.dart';

enum OrderPaymentStatus { fullyPaid, partiallyPaid, unpaid }

class WhatsAppUtils {
  WhatsAppUtils._();

  // ── Singleton Dio instance — avoids re-creating a client on every share ──
  static Dio? _dioInstance;
  static Dio get _dio => _dioInstance ??= Dio();

  // ── Cached result of navigator.canShare(files) — never changes per session ──
  static bool? _canShareFilesCache;

  /// Pre-fetches the receipt image bytes in the background.
  /// Call this as soon as the WhatsApp reminder sheet opens so the download
  /// is (mostly) done by the time the user taps "SEND ON WHATSAPP".
  /// Returns null silently on any error — the share flow falls back gracefully.
  static Future<Uint8List?> prefetchImageBytes(String imageUrl) async {
    if (imageUrl.isEmpty || imageUrl == 'null') return null;
    try {
      final response = await _dio.get<List<int>>(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.data == null) return null;
      return Uint8List.fromList(response.data!);
    } catch (e) {
      debugPrint('⚠️ WhatsApp prefetch failed (will retry on share): $e');
      return null;
    }
  }


  /// Formats double amount into Indian Rupee format (e.g., ₹1,25,000)
  /// Strips the parenthetical Marathi/regional-script suffix from a bilingual
  /// customer name so greetings show only the primary name.
  /// e.g. "Patange Electricals (पतंगे इलेक्ट्रिक्लस)" → "Patange Electricals"
  static String _cleanDisplayName(String name) {
    final trimmed = name.trim();
    final idx = trimmed.indexOf('(');
    // Only strip if the bracket is not the very first character
    if (idx > 0) return trimmed.substring(0, idx).trim();
    return trimmed;
  }

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

  /// Inserts a block of text (like a link or detail) right before the thank you/sign-off section.
  /// If there's a custom note block, the text is inserted before the note block to keep the note as the final footer item.
  static String insertBeforeSignoff(String caption, String textToInsert) {
    const signoffMarker = 'Thank you! 🙏';
    final signoffIndex = caption.lastIndexOf(signoffMarker);
    if (signoffIndex > 0) {
      final bodyPart = caption.substring(0, signoffIndex).trimRight();
      final signoffPart = caption.substring(signoffIndex);

      // Look for a custom note block prefix to insert the text before it
      final noteIndex = bodyPart.lastIndexOf('👉');
      if (noteIndex > 0 && bodyPart.substring(noteIndex).contains('Note:')) {
        final beforeNote = bodyPart.substring(0, noteIndex).trimRight();
        final notePart = bodyPart.substring(noteIndex);
        return '$beforeNote\n\n$textToInsert\n\n$notePart\n\n$signoffPart';
      }

      return '$bodyPart\n\n$textToInsert\n\n$signoffPart';
    }
    return '$caption\n\n$textToInsert';
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
    String? whatsappCustomNote,
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

    final noteSuffix = (whatsappCustomNote != null && whatsappCustomNote.trim().isNotEmpty)
        ? '\n\n👉 *Note:* ${whatsappCustomNote.trim()}'
        : '';

    switch (status) {
      case OrderPaymentStatus.unpaid:
        // Unpaid: show Total = Balance Due
        return 'Hi ${_cleanDisplayName(customerName)},\n'
            'Your order #$orderNumber from *${businessName.trim()}* is ready. 📝\n\n'
            '📋 Total:             $totalFmt\n'
            '✅ Amount Paid:  ₹0\n'
            '⚡ *Balance Due: $totalFmt*'
            '$extraTexts'
            '$noteSuffix\n\n'
            'Thank you! 🙏\n— *${businessName.trim()}*';

      case OrderPaymentStatus.partiallyPaid:
        // Partial: show all 3 lines clearly
        return 'Hi ${_cleanDisplayName(customerName)},\n'
            'Your order #$orderNumber from *${businessName.trim()}* has a partial payment. 📝\n\n'
            '📋 Total:             $totalFmt\n'
            '✅ Amount Paid:  $paidFmt\n'
            '⚡ *Balance Due: $pendingFmt*'
            '$extraTexts'
            '$noteSuffix\n\n'
            'Thank you! 🙏\n— *${businessName.trim()}*';

      case OrderPaymentStatus.fullyPaid:
        // Fully paid: show total = amount paid, balance = ₹0
        return 'Hi ${_cleanDisplayName(customerName)},\n'
            'Your order #$orderNumber from *${businessName.trim()}* is confirmed. ✅\n\n'
            '📋 Total:             $totalFmt\n'
            '✅ Amount Paid:  $totalFmt\n'
            '✓ *Balance Due:  ₹0*'
            '$extraTexts'
            '$noteSuffix\n\n'
            'Thank you! 🙏\n— *${businessName.trim()}*';
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
            final isSharingPhoto = shareOriginalImage &&
                imageUrl != null &&
                imageUrl.isNotEmpty &&
                imageUrl != 'null';

            final message = isSharingPhoto
                ? caption
                : insertBeforeSignoff(caption, 'View details:\n$shareUrl');

            if (isSharingPhoto) {
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
    String? whatsappCustomNote,
  }) {
    final name = _cleanDisplayName(customerName);
    final shop = shopName.trim();

    final noteSuffix = (whatsappCustomNote != null && whatsappCustomNote.trim().isNotEmpty)
        ? '\n\n👉 *Note:* ${whatsappCustomNote.trim()}'
        : '';

    if (useReceiptPhoto &&
        receiptPhotoUrl != null &&
        receiptPhotoUrl.isNotEmpty &&
        receiptPhotoUrl != 'null') {
      final invoiceRef =
          receiptNumber != null ? ' (Bill #$receiptNumber)' : '';
      return 'Hi $name,\n\n'
          '⚠️ *Amount Due: ${formatIndianCurrency(balanceDue)}*$invoiceRef\n\n'
          'Please settle this amount as soon as possible.'
          '$noteSuffix\n\n'
          'Thank you! 🙏\n'
          '— *$shop*';
    }

    // Account Statement mode.
    // Guard: if both totalBilled and totalPaid are 0 (data hasn't loaded yet
    // due to a race condition), skip the breakdown to avoid sending a confusing
    // "Total Bill: ₹0 / Amount Paid: ₹0" message.
    final bool hasBillingData = totalBilled > 0 || totalPaid > 0;

    String msg = 'Hi $name,\n\n'
        '⚠️ *Total Balance Due: ${formatIndianCurrency(balanceDue)}*\n\n';

    if (hasBillingData) {
      msg += '📋 Total Billed: ${formatIndianCurrency(totalBilled)}\n'
          '✅ Amount Paid: ${formatIndianCurrency(totalPaid)}\n'
          '⏳ Balance Due: *${formatIndianCurrency(balanceDue)}*\n\n';
    }

    final isSpecificReceipt = statementLink.contains('receipt.html?i=');
    msg += isSpecificReceipt
        ? '🧾 View Receipt:\n$statementLink\n'
        : '🧾 View full account statement:\n$statementLink\n';

    if (upiId != null && upiId.isNotEmpty) {
      msg += '\n💳 Pay via UPI: $upiId';
    }

    msg += '$noteSuffix\n\nThank you! 🙏\n'
        '— *$shop*';
    return msg;
  }

  /// Downloads an image and shares it natively via the system share sheet.
  ///
  /// On Flutter Web/PWA: fetches image as raw bytes and uses [XFile.fromData]
  /// which triggers the Web Share API with files — the ONLY approach that works
  /// on a mobile browser/PWA (file paths & getTemporaryDirectory don't exist on web).
  ///
  /// On native (Android/iOS): falls back to downloading to a temp file path.
  ///
  /// IMPORTANT: The Web Share API with files is NOT universally supported.
  /// On unsupported PWA platforms, this gracefully falls back to opening WhatsApp
  /// with the direct image URL so the recipient can tap it to view the receipt.
  static Future<void> shareActualImageOnWhatsApp({
    required BuildContext context,
    required String imageUrl,
    required String caption,
    String? phone,
    Uint8List? prefetchedBytes,  // ← pre-warmed bytes from prefetchImageBytes()
    String? receiptNumber,  // used to build clean fallback link
    String? username,       // used to build clean fallback link
  }) async {
    ScaffoldMessengerState? messenger;
    if (context.mounted) {
      messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 14),
              Text('Preparing receipt image…'),
            ],
          ),
          duration: Duration(seconds: 30),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    try {


      if (kIsWeb) {
        // ── WEB / PWA PATH ─────────────────────────────────────────────────
        // Use pre-warmed bytes if available (sheet opened them in background).
        // Fall back to downloading now only if the prefetch didn't complete.
        Uint8List? bytes = prefetchedBytes;
        if (bytes == null) {
          final response = await _dio.get<List<int>>(
            imageUrl,
            options: Options(responseType: ResponseType.bytes),
          );
          if (response.data != null) bytes = Uint8List.fromList(response.data!);
        }
        if (bytes == null) throw Exception('Failed to load receipt image bytes');

        final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';

        if (context.mounted) messenger?.hideCurrentSnackBar();

        // Try Web Share API with files (works on Android Chrome, iOS Safari 15+).
        // On unsupported platforms (desktop Chrome, Firefox, etc.) this gracefully
        // falls through to the browser-download path.
        if (_canShareFiles()) {
          try {
            final result = await SharePlus.instance.share(
              ShareParams(
                files: [XFile.fromData(bytes, mimeType: 'image/jpeg', name: fileName)],
                text: caption,
              ),
            );
            // Success or dismissed — nothing more to do.
            if (result.status == ShareResultStatus.success ||
                result.status == ShareResultStatus.dismissed) {
              return;
            }
            debugPrint('⚠️ Web Share status: ${result.status}. Falling back to download.');
          } catch (e) {
            debugPrint('⚠️ Web Share API threw: $e. Falling back to download.');
          }
        } else {
          debugPrint('⚠️ navigator.canShare(files) not supported — using browser download.');
        }

        // ── FALLBACK: send receipt.html?view=photo link ──────────────────────
        // WhatsApp renders this as a rich preview card showing the receipt
        // image thumbnail (via og:image) — no manual attachment needed.
        if (context.mounted) {
          await _fallbackShareWithImageUrl(
            context,
            phone: phone,
            caption: caption,
            imageUrl: imageUrl,
            receiptNumber: receiptNumber,
            username: username,
          );
        }
      } else {
        // ── NATIVE (Android / iOS) PATH ────────────────────────────────────
        final tempDir = await getTemporaryDirectory();
        final tempFilePath = '${tempDir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';

        await _dio.download(imageUrl, tempFilePath);

        if (context.mounted) messenger?.hideCurrentSnackBar();

        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(tempFilePath, mimeType: 'image/jpeg')],
            text: caption,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error sharing receipt image: $e');
      if (context.mounted) messenger?.hideCurrentSnackBar();
      if (!context.mounted) return;
      await _fallbackShareWithImageUrl(
        context,
        phone: phone,
        caption: caption,
        imageUrl: imageUrl,
        receiptNumber: receiptNumber,
        username: username,
      );
    }
  }

  /// Fallback: when file-based sharing fails on desktop/web, send a link to the
  /// server-rendered photo-preview page which has static og:image in its `<head>`.
  /// WhatsApp's crawler reads these tags (no JS executed) and shows the receipt
  /// image as a rich preview card — no manual attachment needed by the user.
  static Future<void> _fallbackShareWithImageUrl(
    BuildContext context, {
    String? phone,
    required String caption,
    required String imageUrl,
    String? receiptNumber,
    String? username,
  }) async {
    // Use the server-rendered /photo-preview endpoint which has og:image baked
    // into the static HTML <head>. WhatsApp's crawler can read these tags without
    // executing JavaScript, so it renders a rich image preview card in the chat.
    final String receiptPageUrl;
    if (receiptNumber != null &&
        receiptNumber.isNotEmpty &&
        username != null &&
        username.isNotEmpty) {
      // Use clean branded short URL: snapkhata.com/r/{user}/{receipt}
      // Nginx proxies this to the backend photo-preview endpoint internally.
      receiptPageUrl =
          'https://snapkhata.com/r'
          '/${Uri.encodeComponent(username)}'
          '/${Uri.encodeComponent(receiptNumber)}';
    } else {
      // Last resort: use the raw CDN URL directly (still tappable in WhatsApp)
      receiptPageUrl = imageUrl;
    }

    // Place the receipt link BEFORE the sign-off/note for a professional look
    final fallbackMessage = insertBeforeSignoff(caption, '🧾 View Receipt:\n$receiptPageUrl');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📤 Opening WhatsApp with receipt link…'),
          backgroundColor: Color(0xFF25D366),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    }
    await openWhatsAppChat(phone: phone, message: fallbackMessage);
  }

  /// Formats manual entry details as a beautiful text bill and shares it.
  ///
  /// Pass [balanceDue] (the running party balance) to append an outstanding
  /// balance line. If [items] is empty, falls back to a clean bill-amount line.
  static String buildManualBillMessage({
    required String customerName,
    required String shopName,
    required List<Map<String, dynamic>> items,
    required double total,
    required String paymentMode,
    double? receivedAmount,
    double? balanceDue,
    String? whatsappCustomNote,
    DateTime? orderDate,
    DateTime? deliveryDate,
  }) {
    final cleanName = _cleanDisplayName(customerName);
    final totalFmt = formatIndianCurrency(total);

    final buffer = StringBuffer();
    buffer.writeln('Hi *$cleanName*,');
    buffer.writeln('Here\'s your bill from *${shopName.trim()}* 🧾\n');

    if (items.isNotEmpty) {
      buffer.writeln('📦 *Items:*');
      for (final item in items) {
        final name = item['name'] ?? item['item_name'] ?? '';
        final qty = item['quantity'] ?? 1.0;
        final rate = item['rate'] ?? 0.0;
        final amount = item['amount'] ?? (qty * rate);

        final qtyStr = qty % 1 == 0 ? qty.toInt().toString() : qty.toString();
        final rawUnit = (item['unit']?.toString() ?? '').trim().toUpperCase();
        final unit = (rawUnit == 'NOS' || rawUnit.isEmpty) ? '' : rawUnit;
        final rateFmt = formatIndianCurrency(rate.toDouble());
        final amountFmt = formatIndianCurrency(amount.toDouble());

        if (qty == 1 && unit.isEmpty) {
          buffer.writeln('• *$name* @ $rateFmt — *$amountFmt*');
        } else {
          final unitPart = unit.isNotEmpty ? ' $unit' : '';
          buffer.writeln('• *$name* × $qtyStr$unitPart @ $rateFmt — *$amountFmt*');
        }
      }
      buffer.writeln();
      buffer.writeln('*Total Bill: $totalFmt*');
    } else {
      // No item breakdown — just show the total cleanly
      buffer.writeln('📋 *Bill Amount: $totalFmt*');
    }

    if (receivedAmount != null) {
      final double paid = receivedAmount;
      final double pending = total - paid;
      buffer.writeln('✅ Amount Paid: ${formatIndianCurrency(paid)}');
      if (pending > 0.01) {
        buffer.writeln('⏳ Remaining Bill Balance: ${formatIndianCurrency(pending)}');
      }
    }

    // Append running balance due only when there's an outstanding amount
    if (balanceDue != null && balanceDue > 0.01) {
      buffer.writeln('\n⚠️ *Total Balance Due: ${formatIndianCurrency(balanceDue)}*');
    }

    // Laundry-style: show order + delivery promise dates when provided
    if (orderDate != null && deliveryDate != null) {
      final orderStr = _formatMessageDate(orderDate);
      final deliveryStr = _formatMessageDate(deliveryDate);
      buffer.writeln('\n📅 *Order Date:* $orderStr');
      buffer.writeln('🚚 *Delivery Promise:* $deliveryStr');
    }

    if (whatsappCustomNote != null && whatsappCustomNote.trim().isNotEmpty) {
      buffer.writeln('\n👉 *Note:* ${whatsappCustomNote.trim()}');
    }

    buffer.writeln('\nThank you! 🙏\n— *${shopName.trim()}*');

    return buffer.toString();
  }

  /// Formats a DateTime as "27 May 2026" for WhatsApp messages.
  static String _formatMessageDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  /// Returns true only if the browser's Web Share API supports sharing files.
  /// Checks [navigator.canShare] with a dummy image file — if this returns
  /// false or throws (older Chrome, Firefox, iOS Safari < 15), we use the
  /// browser-download fallback instead.
  static bool _canShareFiles() {
    // Cache the result — browser capabilities never change within a session.
    if (_canShareFilesCache != null) return _canShareFilesCache!;
    if (!kIsWeb) {
      _canShareFilesCache = true;
      return true; // native always supports file sharing
    }
    try {
      // Check navigator.share exists (not available in all browsers)
      final navShare = _jsEval('typeof navigator.share === "function"');
      if (navShare != 'true') {
        _canShareFilesCache = false;
        return false;
      }

      // Check navigator.canShare exists
      final navCanShare = _jsEval('typeof navigator.canShare === "function"');
      if (navCanShare != 'true') {
        _canShareFilesCache = false;
        return false;
      }

      // Check canShare with a dummy file object
      final canShare = _jsEval(
        'navigator.canShare({ files: [new File([], "t.jpg", {type:"image/jpeg"})] }).toString()',
      );
      _canShareFilesCache = canShare == 'true';
      return _canShareFilesCache!;
    } catch (_) {
      _canShareFilesCache = false;
      return false; // degrade gracefully
    }
  }

}

/// Thin wrapper so call-sites inside this file use the private-looking name.
/// The real implementation lives in js_interop_web.dart (web) / js_interop_stub.dart (native).
String _jsEval(String code) => jsEval(code);
