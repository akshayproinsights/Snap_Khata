import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mobile/core/theme/app_theme.dart';

/// On non-web platforms, renders a custom, premium Google Sign-In button.
Widget renderGoogleSignInButton({VoidCallback? onPressed}) {
  return Builder(
    builder: (context) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: context.borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: context.surfaceColor,
          elevation: 0,
        ),
        icon: const FaIcon(
          FontAwesomeIcons.google,
          color: Colors.redAccent,
          size: 18,
        ),
        label: Text(
          'Sign in with Google',
          style: TextStyle(
            color: context.textColor,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      );
    },
  );
}
