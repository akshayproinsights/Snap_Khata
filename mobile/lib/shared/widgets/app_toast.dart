import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:toastification/toastification.dart';
import 'package:flutter/services.dart';

enum ToastType { success, error, warning, info }

class AppToast {
  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.success,
    String? title,
    Duration duration = const Duration(seconds: 4),
  }) {
    // Determine style based on type
    ToastificationType toastType;
    Color primaryColor;

    switch (type) {
      case ToastType.success:
        toastType = ToastificationType.success;
        primaryColor = AppTheme.success;
        HapticFeedback.lightImpact();
        break;
      case ToastType.error:
        toastType = ToastificationType.error;
        primaryColor = AppTheme.error;
        HapticFeedback.mediumImpact();
        break;
      case ToastType.warning:
        toastType = ToastificationType.warning;
        primaryColor = Colors.orange;
        HapticFeedback.lightImpact();
        break;
      case ToastType.info:
        toastType = ToastificationType.info;
        primaryColor = AppTheme.primary;
        break;
    }

    toastification.show(
      context: context,
      type: toastType,
      style: ToastificationStyle.flatColored,
      title: title != null
          ? Text(title, style: const TextStyle(fontWeight: FontWeight.bold))
          : null,
      description:
          Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
      alignment: Alignment.topCenter,
      autoCloseDuration: duration,
      animationBuilder: (
        context,
        animation,
        alignment,
        child,
      ) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      primaryColor: primaryColor,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      borderRadius: BorderRadius.circular(12),
      boxShadow: highModeShadow,
      showProgressBar: false,
      closeOnClick: true,
      pauseOnHover: true,
    );
  }

  static void showSuccess(BuildContext context, String message,
      {String? title}) {
    show(context, message: message, type: ToastType.success, title: title);
  }

  static void showError(BuildContext context, String message, {String? title}) {
    show(context, message: message, type: ToastType.error, title: title);
  }

  static void showWarning(BuildContext context, String message,
      {String? title}) {
    show(context, message: message, type: ToastType.warning, title: title);
  }
}
