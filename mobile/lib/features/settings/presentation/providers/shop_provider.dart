import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/settings/domain/models/shop_profile.dart';
import 'dart:developer' as developer;

final shopProvider = NotifierProvider<ShopNotifier, ShopProfile>(ShopNotifier.new);

class ShopNotifier extends Notifier<ShopProfile> {
  bool _isInitialized = false;

  /// Tracks the in-flight init/refresh so callers can await it.
  /// Replaced on every forceRefresh() call.
  Future<void>? _initFuture;

  bool get isInitialized => _isInitialized;

  @override
  ShopProfile build() {
    developer.log('ShopNotifier.build() called', name: 'ShopProvider');
    _isInitialized = false;
    _initFuture = Future.microtask(() => _doInit());
    return ShopProfile();
  }

  // ── Key helpers ─────────────────────────────────────────────────────────────

  /// Returns the SharedPreferences key scoped to [username].
  /// Falls back to the legacy unscoped key when username is empty.
  String _prefKey(String base, String username) =>
      username.isEmpty ? base : '${base}_$username';

  /// Reads the stored username from SharedPreferences (written by authProvider on login).
  Future<String> _getStoredUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_username') ?? '';
  }

  // ── Init ────────────────────────────────────────────────────────────────────

  Future<void> _doInit() async {
    developer.log('ShopNotifier._doInit() started', name: 'ShopProvider');
    try {
      final username = await _getStoredUsername();
      await loadFromPrefs(username: username);
      await syncWithBackend();
    } catch (e) {
      developer.log('ShopNotifier._doInit() error: $e', name: 'ShopProvider');
    } finally {
      _isInitialized = true;
    }
    developer.log(
      'ShopNotifier._doInit() completed. name="${state.name}"',
      name: 'ShopProvider',
    );
  }

  // ── Load from local cache ────────────────────────────────────────────────────

  Future<void> loadFromPrefs({String? username}) async {
    developer.log('ShopNotifier.loadFromPrefs() started', name: 'ShopProvider');
    final u = username ?? await _getStoredUsername();
    final prefs = await SharedPreferences.getInstance();

    // Read scoped key with migration fallback to legacy unscoped key.
    String read(String base) =>
        prefs.getString(_prefKey(base, u)) ?? prefs.getString(base) ?? '';

    final cachedName      = read('shop_title');
    final cachedAddress   = read('shop_address');
    final cachedPhone     = read('shop_phone');
    final cachedGst       = read('shop_gst');
    final cachedUpi       = read('shop_upi_id');
    final cachedLogoUrl   = read('shop_logo_url');
    final cachedTerms     = read('shop_custom_terms');
    final cachedWaNote    = read('whatsapp_custom_note');
    final cachedShopType  = read('shop_type');

    developer.log(
      'Cached shop name: "$cachedName" (user: "$u")',
      name: 'ShopProvider',
    );

    state = ShopProfile(
      name: cachedName,
      address: cachedAddress,
      phone: cachedPhone,
      gst: cachedGst,
      upiId: cachedUpi,
      logoUrl: cachedLogoUrl,
      customTerms: cachedTerms,
      whatsappCustomNote: cachedWaNote,
      shopType: cachedShopType.isEmpty ? 'general' : cachedShopType,
    );
    developer.log('ShopNotifier.loadFromPrefs() completed', name: 'ShopProvider');
  }

  // ── Backend sync ─────────────────────────────────────────────────────────────

  Future<void> syncWithBackend() async {
    developer.log('ShopNotifier.syncWithBackend() started', name: 'ShopProvider');
    try {
      final response = await ApiClient().dio.get('/api/shop-profile');
      developer.log(
        'Backend response status: ${response.statusCode}',
        name: 'ShopProvider',
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;

        final newProfile = ShopProfile(
          name:              (data['shop_name']            as String?) ?? '',
          address:           (data['shop_address']         as String?) ?? '',
          phone:             (data['shop_phone']           as String?) ?? '',
          gst:               (data['shop_gst']             as String?) ?? '',
          upiId:             (data['shop_upi_id']          as String?) ?? '',
          logoUrl:           (data['shop_logo_url']        as String?) ?? '',
          customTerms:       (data['custom_terms']         as String?) ?? '',
          whatsappCustomNote:(data['whatsapp_custom_note'] as String?) ?? '',
          shopType:          (data['shop_type']            as String?) ?? 'general',
        );

        developer.log(
          'Backend shop name: "${newProfile.name}" | local: "${state.name}"',
          name: 'ShopProvider',
        );

        // Always apply the backend response — it is the authoritative source of truth.
        // We merge carefully: keep local name if backend returned empty, but always
        // sync logo_url and other fields that may have been updated from another device.
        final mergedProfile = ShopProfile(
          name: newProfile.name.isNotEmpty ? newProfile.name : state.name,
          address: newProfile.address.isNotEmpty ? newProfile.address : state.address,
          phone: newProfile.phone.isNotEmpty ? newProfile.phone : state.phone,
          gst: newProfile.gst.isNotEmpty ? newProfile.gst : state.gst,
          upiId: newProfile.upiId.isNotEmpty ? newProfile.upiId : state.upiId,
          // Logo URL: always use backend value (even empty means user removed it).
          // If backend has a URL, it is authoritative. Only keep local if backend is blank
          // AND local is non-empty (i.e. just uploaded but not yet synced).
          logoUrl: newProfile.logoUrl.isNotEmpty
              ? newProfile.logoUrl
              : (state.logoUrl.isNotEmpty ? state.logoUrl : ''),
          customTerms: newProfile.customTerms.isNotEmpty ? newProfile.customTerms : state.customTerms,
          whatsappCustomNote: newProfile.whatsappCustomNote.isNotEmpty
              ? newProfile.whatsappCustomNote
              : state.whatsappCustomNote,
          shopType: newProfile.shopType.isNotEmpty ? newProfile.shopType : state.shopType,
        );

        state = mergedProfile;

        // Persist to username-scoped cache.
        final username = await _getStoredUsername();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefKey('shop_title',           username), mergedProfile.name);
        await prefs.setString(_prefKey('shop_address',         username), mergedProfile.address);
        await prefs.setString(_prefKey('shop_phone',           username), mergedProfile.phone);
        await prefs.setString(_prefKey('shop_gst',             username), mergedProfile.gst);
        await prefs.setString(_prefKey('shop_upi_id',          username), mergedProfile.upiId);
        await prefs.setString(_prefKey('shop_logo_url',        username), mergedProfile.logoUrl);
        await prefs.setString(_prefKey('shop_custom_terms',    username), mergedProfile.customTerms);
        await prefs.setString(_prefKey('whatsapp_custom_note', username), mergedProfile.whatsappCustomNote);
        await prefs.setString(_prefKey('shop_type',            username), mergedProfile.shopType);

        developer.log(
          'Synced shop profile from backend. name="${mergedProfile.name}" logoUrl="${mergedProfile.logoUrl}"',
          name: 'ShopProvider',
        );
      }
    } catch (e) {
      developer.log('Error syncing with backend: $e', name: 'ShopProvider');
    }
    developer.log('ShopNotifier.syncWithBackend() completed', name: 'ShopProvider');
  }

  // ── Update (save) ────────────────────────────────────────────────────────────

  Future<void> updateProfile(ShopProfile profile) async {
    developer.log(
      'ShopNotifier.updateProfile() name="${profile.name}"',
      name: 'ShopProvider',
    );
    state = profile;

    // Save to username-scoped local cache.
    final username = await _getStoredUsername();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey('shop_title',           username), profile.name);
    await prefs.setString(_prefKey('shop_address',         username), profile.address);
    await prefs.setString(_prefKey('shop_phone',           username), profile.phone);
    await prefs.setString(_prefKey('shop_gst',             username), profile.gst);
    await prefs.setString(_prefKey('shop_upi_id',          username), profile.upiId);
    await prefs.setString(_prefKey('shop_logo_url',        username), profile.logoUrl);
    await prefs.setString(_prefKey('shop_custom_terms',    username), profile.customTerms);
    await prefs.setString(_prefKey('whatsapp_custom_note', username), profile.whatsappCustomNote);
    await prefs.setString(_prefKey('shop_type',            username), profile.shopType);

    // Push to backend.
    try {
      await ApiClient().dio.post('/api/shop-profile', data: {
        'shop_name':            profile.name,
        'shop_address':         profile.address,
        'shop_phone':           profile.phone,
        'shop_gst':             profile.gst,
        'shop_upi_id':          profile.upiId,
        'shop_logo_url':        profile.logoUrl,
        'custom_terms':         profile.customTerms,
        'whatsapp_custom_note': profile.whatsappCustomNote,
        'shop_type':            profile.shopType,
      });
      developer.log('Shop profile saved to backend successfully', name: 'ShopProvider');
    } catch (e) {
      developer.log('Error saving shop profile to backend: $e', name: 'ShopProvider');
    }
  }

  // ── Lifecycle helpers ────────────────────────────────────────────────────────

  /// Clears in-memory state. Call from authProvider on logout so the next
  /// user starts with a clean slate.
  Future<void> resetState() async {
    developer.log('ShopNotifier.resetState() called', name: 'ShopProvider');
    state = ShopProfile();
    _isInitialized = false;
    _initFuture = null;
  }

  /// Re-runs the full init cycle (reads stored username → prefs → backend).
  /// Call from authProvider after a successful login/Google sign-in so the
  /// newly authenticated user's shop data is loaded immediately.
  Future<void> forceRefresh() async {
    developer.log('ShopNotifier.forceRefresh() called', name: 'ShopProvider');
    _isInitialized = false;
    _initFuture = _doInit();
    await _initFuture;
  }

  // ── Validation helpers ───────────────────────────────────────────────────────

  /// Returns true if the state already has a non-empty shop name.
  bool isProfileInitialized() => state.name.isNotEmpty;

  /// Returns the shop name, or "Our Shop" as a last-resort fallback.
  String getShopNameWithFallback() {
    if (state.name.isNotEmpty) return state.name;
    developer.log('Shop name empty — using fallback "Our Shop"', name: 'ShopProvider');
    return 'Our Shop';
  }

  /// Waits for the current init/refresh to finish, then ensures we have a
  /// valid shop name. Returns false only when genuinely unavailable.
  ///
  /// **Always call this before reading shopProvider in async WhatsApp/share
  /// callbacks** — it eliminates the race condition that produced "Our Shop".
  Future<bool> ensureValidShopName() async {
    // Await the in-flight init so we don't race against the first microtask.
    final f = _initFuture;
    if (f != null) {
      try { await f; } catch (_) {}
    }

    if (state.name.isNotEmpty) {
      developer.log('Shop name valid: "${state.name}"', name: 'ShopProvider');
      return true;
    }

    // One more explicit attempt if somehow still empty.
    developer.log(
      'Shop name empty after init — trying explicit sync',
      name: 'ShopProvider',
    );
    await syncWithBackend();

    if (state.name.isEmpty) {
      developer.log('Shop name still empty after sync', name: 'ShopProvider');
      return false;
    }
    return true;
  }

  /// [ensureValidShopName] + shows an AlertDialog if name is unavailable.
  Future<String> getValidatedShopName(BuildContext context) async {
    final isValid = await ensureValidShopName();
    if (!isValid) {
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Shop Name Required'),
            content: const Text(
              'Please set up your shop name in Settings before sending WhatsApp messages.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return 'Our Shop';
    }
    return state.name;
  }
}
