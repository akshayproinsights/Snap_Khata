import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as gsi_web;

/// On web, renders the official Google Sign-In (GSI) button.
/// This button handles the popup internally and emits sign-in events
/// via [GoogleSignIn.instance.authenticationEvents].
Widget renderGoogleSignInButton({VoidCallback? onPressed}) => gsi_web.renderButton();
