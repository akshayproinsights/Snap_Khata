import 'package:flutter/widgets.dart';

/// On non-web platforms, Google Sign-In button is not supported.
Widget renderGoogleSignInButton() => const SizedBox.shrink();
