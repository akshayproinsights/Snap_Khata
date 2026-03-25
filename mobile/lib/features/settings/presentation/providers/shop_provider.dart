import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/settings/domain/models/shop_profile.dart';
import 'dart:developer' as developer;

final shopProvider = NotifierProvider<ShopNotifier, ShopProfile>(ShopNotifier.new);

class ShopNotifier extends Notifier<ShopProfile> {
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  @override
  ShopProfile build() {
    developer.log('ShopNotifier.build() called', name: 'ShopProvider');
    Future.microtask(() => _init());
    return ShopProfile();
  }


  Future<void> _init() async {
    developer.log('ShopNotifier._init() started', name: 'ShopProvider');
    await loadFromPrefs();
    await syncWithBackend();
    _isInitialized = true;
    developer.log('ShopNotifier._init() completed. Shop name: "${state.name}", isInitialized: $_isInitialized', name: 'ShopProvider');
  }

  Future<void> loadFromPrefs() async {
    developer.log('ShopNotifier.loadFromPrefs() started', name: 'ShopProvider');
    final prefs = await SharedPreferences.getInstance();
    final cachedName = prefs.getString('shop_title') ?? '';
    final cachedAddress = prefs.getString('shop_address') ?? '';
    final cachedPhone = prefs.getString('shop_phone') ?? '';
    final cachedGst = prefs.getString('shop_gst') ?? '';
    
    developer.log('Cached shop name: "$cachedName"', name: 'ShopProvider');
    developer.log('Cached shop address: "$cachedAddress"', name: 'ShopProvider');
    developer.log('Cached shop phone: "$cachedPhone"', name: 'ShopProvider');
    developer.log('Cached shop GST: "$cachedGst"', name: 'ShopProvider');
    
    state = ShopProfile(
      name: cachedName,
      address: cachedAddress,
      phone: cachedPhone,
      gst: cachedGst,
    );
    developer.log('ShopNotifier.loadFromPrefs() completed', name: 'ShopProvider');
  }

  Future<void> syncWithBackend() async {
    developer.log('ShopNotifier.syncWithBackend() started', name: 'ShopProvider');
    try {
      final response = await ApiClient().dio.get('/api/shop-profile');
      developer.log('Backend API response status: ${response.statusCode}', name: 'ShopProvider');
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        developer.log('Backend API data: $data', name: 'ShopProvider');
        
        final newProfile = ShopProfile(
          name: (data['shop_name'] as String?) ?? '',
          address: (data['shop_address'] as String?) ?? '',
          phone: (data['shop_phone'] as String?) ?? '',
          gst: (data['shop_gst'] as String?) ?? '',
        );

        developer.log('Parsed shop name from backend: "${newProfile.name}"', name: 'ShopProvider');
        developer.log('Previous shop name: "${state.name}"', name: 'ShopProvider');
        
        state = newProfile;
        
        // Update local cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('shop_title', newProfile.name);
        await prefs.setString('shop_address', newProfile.address);
        await prefs.setString('shop_phone', newProfile.phone);
        await prefs.setString('shop_gst', newProfile.gst);
        
        developer.log('Updated SharedPreferences cache with new shop data', name: 'ShopProvider');
      } else {
        developer.log('Backend API returned non-200 status or empty data', name: 'ShopProvider');
      }
    } catch (e) {
      developer.log('Error syncing with backend: $e', name: 'ShopProvider');
      // Best effort sync
    }
    developer.log('ShopNotifier.syncWithBackend() completed', name: 'ShopProvider');
  }

  Future<void> updateProfile(ShopProfile profile) async {
    developer.log('ShopNotifier.updateProfile() called with name: "${profile.name}"', name: 'ShopProvider');
    state = profile;
    
    // Save locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shop_title', profile.name);
    await prefs.setString('shop_address', profile.address);
    await prefs.setString('shop_phone', profile.phone);
    await prefs.setString('shop_gst', profile.gst);

    // Save to backend
    try {
      await ApiClient().dio.post('/api/shop-profile', data: {
        'shop_name': profile.name,
        'shop_address': profile.address,
        'shop_phone': profile.phone,
        'shop_gst': profile.gst,
      });
      developer.log('Shop profile saved to backend successfully', name: 'ShopProvider');
    } catch (e) {
      developer.log('Error saving shop profile to backend: $e', name: 'ShopProvider');
      // Best effort sync
    }
  }

  /// Force refresh the shop profile from backend
  Future<void> forceRefresh() async {
    developer.log('ShopNotifier.forceRefresh() called', name: 'ShopProvider');
    await syncWithBackend();
  }

  /// Check if shop profile is properly initialized (has a non-empty name)
  bool isProfileInitialized() {
    return state.name.isNotEmpty;
  }

  /// Get the shop name with fallback logic
  String getShopNameWithFallback() {
    if (state.name.isNotEmpty) {
      return state.name;
    } else {
      developer.log('Shop name is empty, using fallback "Our Shop"', name: 'ShopProvider');
      return 'Our Shop';
    }
  }

  /// Ensure shop profile is loaded and has a valid name
  /// Returns true if shop name is valid, false otherwise
  Future<bool> ensureValidShopName() async {
    if (!_isInitialized) {
      developer.log('Shop profile not initialized yet, waiting...', name: 'ShopProvider');
      // Wait a bit for initialization
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (state.name.isEmpty) {
      developer.log('Shop name is empty, trying to sync with backend...', name: 'ShopProvider');
      await syncWithBackend();
      
      if (state.name.isEmpty) {
        developer.log('Shop name is still empty after sync', name: 'ShopProvider');
        return false;
      }
    }
    
    developer.log('Shop name is valid: "${state.name}"', name: 'ShopProvider');
    return true;
  }

  /// Get shop name with validation - shows alert if shop name is empty
  Future<String> getValidatedShopName(BuildContext context) async {
    final isValid = await ensureValidShopName();
    
    if (!isValid) {
      developer.log('Shop name is invalid, showing alert to user', name: 'ShopProvider');
      // Show alert to user
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Shop Name Required'),
            content: const Text('Please set up your shop name in Settings before sending WhatsApp messages.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return 'Our Shop'; // Fallback
    }
    
    return state.name;
  }
}
