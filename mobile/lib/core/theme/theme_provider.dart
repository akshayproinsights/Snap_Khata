import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Key used to persist dark mode preference.
const _kDarkModeKey = 'dark_mode_enabled';

/// Riverpod provider that manages the app's theme mode.
/// Persists user choice to SharedPreferences.
class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.light) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_kDarkModeKey) ?? false;
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggleDarkMode({required bool enabled}) async {
    state = enabled ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDarkModeKey, enabled);
  }

  bool get isDark => state == ThemeMode.dark;
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>(
  (ref) => ThemeNotifier(),
);
