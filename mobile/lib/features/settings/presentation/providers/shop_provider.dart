import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/settings/domain/models/shop_profile.dart';

final shopProvider = NotifierProvider<ShopNotifier, ShopProfile>(ShopNotifier.new);

class ShopNotifier extends Notifier<ShopProfile> {
  @override
  ShopProfile build() {
    Future.microtask(() => _init());
    return ShopProfile();
  }


  Future<void> _init() async {
    await loadFromPrefs();
    await syncWithBackend();
  }

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    state = ShopProfile(
      name: prefs.getString('shop_title') ?? '',
      address: prefs.getString('shop_address') ?? '',
      phone: prefs.getString('shop_phone') ?? '',
      gst: prefs.getString('shop_gst') ?? '',
    );
  }

  Future<void> syncWithBackend() async {
    try {
      final response = await ApiClient().dio.get('/api/shop-profile');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final newProfile = ShopProfile(
          name: (data['shop_name'] as String?) ?? '',
          address: (data['shop_address'] as String?) ?? '',
          phone: (data['shop_phone'] as String?) ?? '',
          gst: (data['shop_gst'] as String?) ?? '',
        );

        state = newProfile;
        
        // Update local cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('shop_title', newProfile.name);
        await prefs.setString('shop_address', newProfile.address);
        await prefs.setString('shop_phone', newProfile.phone);
        await prefs.setString('shop_gst', newProfile.gst);
      }
    } catch (e) {
      // Best effort sync
    }
  }

  Future<void> updateProfile(ShopProfile profile) async {
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
    } catch (e) {
      // Best effort sync
    }
  }
}
