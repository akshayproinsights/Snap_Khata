import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';

class ContactUtils {
  static final FlutterNativeContactPicker _contactPicker = FlutterNativeContactPicker();

  static Future<String?> pickContactPhone() async {
    try {
      Contact? contact = await _contactPicker.selectContact();
      if (contact != null && contact.phoneNumbers != null && contact.phoneNumbers!.isNotEmpty) {
        String phone = contact.phoneNumbers!.first;
        // Clean up the phone number
        phone = phone.replaceAll(RegExp(r'\s+|-|\(|\)'), '');
        if (phone.startsWith('+91') && phone.length == 13) {
          phone = phone.substring(3);
        } else if (phone.startsWith('91') && phone.length == 12) {
          phone = phone.substring(2);
        } else if (phone.startsWith('0') && phone.length == 11) {
          phone = phone.substring(1);
        }
        return phone;
      }
    } catch (e) {
      // Ignore
    }
    return null;
  }
}
