import 'package:flutter/foundation.dart' show kIsWeb;

// Conditional import — web implementation vs native stub
import 'contact_utils_stub.dart'
    if (dart.library.js_interop) 'contact_utils_web.dart' as contact_impl;

class ContactUtils {
  /// Pick a phone number from the device contacts.
  ///
  /// - On **Android/iOS native app**: opens the system native contact picker.
  /// - On **PWA/Web** (Android Chrome): uses the Web Contact Picker API
  ///   (`navigator.contacts.select`). Falls back silently on unsupported browsers.
  ///
  /// Always returns a cleaned 10-digit Indian number, or `null` on
  /// cancellation / permission denied / unsupported environment.
  static Future<String?> pickContactPhone() async {
    if (kIsWeb) {
      return contact_impl.pickContactPhoneWeb();
    }
    return contact_impl.pickContactPhoneNative();
  }

  /// Whether the contact picker is supported on the current device and browser.
  static bool get isSupported {
    if (kIsWeb) {
      return contact_impl.isSupportedWeb();
    }
    return contact_impl.isSupportedNative();
  }
}
