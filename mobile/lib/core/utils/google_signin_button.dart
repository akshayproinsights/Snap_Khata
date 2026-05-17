// Conditional import: on web, exposes the real GSI button.
// On non-web platforms, returns an empty widget.
//
// Usage:
//   import 'package:mobile/core/utils/google_signin_button.dart';
//   ...
//   renderGoogleSignInButton()
export 'google_signin_button_stub.dart'
    if (dart.library.html) 'google_signin_button_web.dart';
