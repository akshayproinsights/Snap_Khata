// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';

/// JS interop bindings for the Web Contact Picker API.
/// Supported on Android Chrome 80+ when running as PWA.
/// Not supported on desktop browsers (Chrome/Firefox/Safari desktop).

@JS('navigator')
external NavigatorContacts get _jsNavigator;

extension type NavigatorContacts(JSObject _) implements JSObject {
  external ContactsManager? get contacts;
}

extension type ContactsManager(JSObject _) implements JSObject {
  external JSPromise<JSArray<ContactResult>> select(
    JSArray<JSString> properties,
    JSObject options,
  );
}

extension type ContactResult(JSObject _) implements JSObject {
  external JSArray<JSString>? get tel;
}

/// Returns `null` — native picker is not available on web.
Future<String?> pickContactPhoneNative() async => null;

/// Pick a phone number using the Web Contact Picker API.
/// Returns a cleaned 10-digit Indian mobile number, or `null` on
/// cancellation / unsupported browser / error.
Future<String?> pickContactPhoneWeb() async {
  try {
    final contacts = _jsNavigator.contacts;
    if (contacts == null) {
      // Browser doesn't support the Contact Picker API
      return null;
    }

    final properties = ['tel'.toJS].toJS;
    final options = {'multiple': false}.jsify()! as JSObject;

    final result = await contacts.select(properties, options).toDart;
    if (result.length == 0) return null;

    final contact = result[0];
    final tels = contact.tel;
    if (tels == null || tels.length == 0) return null;

    String phone = tels[0].toDart;

    // Strip spaces, dashes, parentheses
    phone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Normalise to 10-digit Indian number
    if (phone.startsWith('+91') && phone.length == 13) {
      phone = phone.substring(3);
    } else if (phone.startsWith('91') && phone.length == 12) {
      phone = phone.substring(2);
    } else if (phone.startsWith('0') && phone.length == 11) {
      phone = phone.substring(1);
    }

    return phone;
  } catch (_) {
    // User cancelled or unsupported — fail silently
    return null;
  }
}

/// Check if navigator.contacts is supported on the web browser.
bool isSupportedWeb() {
  try {
    return _jsNavigator.contacts != null;
  } catch (_) {
    return false;
  }
}

/// Native contact picker support check (always false in web build context).
bool isSupportedNative() => false;

