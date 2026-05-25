// Native (Android/iOS) contact picker implementation.
// Compiled only on non-web platforms.

import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';

final _nativePicker = FlutterNativeContactPicker();

/// Web path — never called on native, stub returns null.
Future<String?> pickContactPhoneWeb() async => null;

/// Native path — uses flutter_native_contact_picker.
Future<String?> pickContactPhoneNative() async {
  try {
    Contact? contact = await _nativePicker.selectContact();
    if (contact != null &&
        contact.phoneNumbers != null &&
        contact.phoneNumbers!.isNotEmpty) {
      String phone = contact.phoneNumbers!.first;
      // Strip spaces, dashes, parentheses
      phone = phone.replaceAll(RegExp(r'\s+|-|\(|\)'), '');
      // Normalise to 10-digit Indian number
      if (phone.startsWith('+91') && phone.length == 13) {
        phone = phone.substring(3);
      } else if (phone.startsWith('91') && phone.length == 12) {
        phone = phone.substring(2);
      } else if (phone.startsWith('0') && phone.length == 11) {
        phone = phone.substring(1);
      }
      return phone;
    }
  } catch (_) {
    // User cancelled or permission denied — fail silently
  }
  return null;
}

/// Web contact picker support check (always false in native build context).
bool isSupportedWeb() => false;

/// Native contact picker support check (always true in native build context).
bool isSupportedNative() => true;

