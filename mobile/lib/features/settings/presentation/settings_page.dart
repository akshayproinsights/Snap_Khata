import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/theme/theme_provider.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/shared/widgets/mobile_text_field.dart';
import 'package:mobile/core/localization/locale_provider.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/shared/widgets/app_toast.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String _shopName = '';
  String _shopAddress = '';
  String _shopPhone = '';
  String _shopGst = '';
  bool _isLoadingProfile = false;
  bool _geminiConfigLoaded = false;
  String _industry = '';
  bool _isLoadingConfig = false;

  @override
  void initState() {
    super.initState();
    _loadShopDetails();
    _loadConfig();
  }

  /// Load from local cache first for instant UI, then fetch latest from backend.
  Future<void> _loadShopDetails() async {
    // 1. Restore from local cache immediately
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _shopName = prefs.getString('shop_title') ?? '';
      _shopAddress = prefs.getString('shop_address') ?? '';
      _shopPhone = prefs.getString('shop_phone') ?? '';
      _shopGst = prefs.getString('shop_gst') ?? '';
    });

    // 2. Fetch latest from backend
    setState(() => _isLoadingProfile = true);
    try {
      final response = await ApiClient().dio.get('/api/shop-profile');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final name = (data['shop_name'] as String?) ?? '';
        final address = (data['shop_address'] as String?) ?? '';
        final phone = (data['shop_phone'] as String?) ?? '';
        final gst = (data['shop_gst'] as String?) ?? '';

        // Update local cache with backend values
        await prefs.setString('shop_title', name);
        await prefs.setString('shop_address', address);
        await prefs.setString('shop_phone', phone);
        await prefs.setString('shop_gst', gst);

        if (mounted) {
          setState(() {
            _shopName = name;
            _shopAddress = address;
            _shopPhone = phone;
            _shopGst = gst;
          });
        }
      }
    } catch (e) {
      // Backend unavailable — local cache is still displayed, which is fine
      debugPrint('Could not fetch shop profile from backend: $e');
    } finally {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoadingConfig = true);
    try {
      final response = await ApiClient().dio.get('/api/config');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _geminiConfigLoaded = data['gemini_config_loaded'] == true;
            _industry = (data['industry'] as String?) ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint('Could not fetch config: $e');
    } finally {
      if (mounted) setState(() => _isLoadingConfig = false);
    }
  }

  /// Save to both local SharedPreferences and the backend API.
  Future<void> _saveShopDetails() async {
    // Save locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shop_title', _shopName);
    await prefs.setString('shop_address', _shopAddress);
    await prefs.setString('shop_phone', _shopPhone);
    await prefs.setString('shop_gst', _shopGst);

    // Save to backend (best-effort — don't block if offline)
    try {
      await ApiClient().dio.post('/api/shop-profile', data: {
        'shop_name': _shopName,
        'shop_address': _shopAddress,
        'shop_phone': _shopPhone,
        'shop_gst': _shopGst,
      });
    } catch (e) {
      debugPrint('Could not sync shop profile to backend: $e');
      // Offline — SyncQueueService will retry automatically later
    }
  }

  void _showShopDetailsSheet() {
    // Local copies editable inside the sheet
    String tempName = _shopName;
    String tempAddress = _shopAddress;
    String tempPhone = _shopPhone;
    String tempGst = _shopGst;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Shop Details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'This info appears on your invoices & syncs across devices',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              MobileTextField(
                initialValue: tempName,
                placeholder: 'Shop Name',
                onSave: (val) => tempName = val,
              ),
              const SizedBox(height: 12),
              MobileTextField(
                initialValue: tempAddress,
                placeholder: 'Complete Address',
                onSave: (val) => tempAddress = val,
              ),
              const SizedBox(height: 12),
              MobileTextField(
                initialValue: tempPhone,
                placeholder: 'Phone Number',
                onSave: (val) => tempPhone = val,
              ),
              const SizedBox(height: 12),
              MobileTextField(
                initialValue: tempGst,
                placeholder: 'GSTIN (Optional)',
                onSave: (val) => tempGst = val,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      _shopName = tempName;
                      _shopAddress = tempAddress;
                      _shopPhone = tempPhone;
                      _shopGst = tempGst;
                    });
                    await _saveShopDetails();
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    if (mounted) {
                      AppToast.showSuccess(
                          context, 'Shop details saved & synced');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Save & Sync',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(authProvider);
    final String userName =
        userState.user?.name ?? userState.user?.username ?? 'User';
    final String userEmail = userState.user?.email ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Profile & Settings',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Profile Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.primary.withOpacity(0.1),
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (userEmail.isNotEmpty)
                        Text(
                          userEmail,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      if (_shopName.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            _isLoadingProfile ? 'Syncing...' : _shopName,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Settings Options
          const Text(
            'Preferences',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildSettingsTile(
            icon: LucideIcons.store,
            title: 'Shop Details',
            subtitle: _shopName.isNotEmpty ? _shopName : 'Tap to set up',
            onTap: _showShopDetailsSheet,
          ),
          _buildSettingsTile(
            icon: LucideIcons.moon,
            title: 'Dark Mode',
            trailing: Switch(
              value: ref.watch(themeProvider) == ThemeMode.dark,
              onChanged: (val) {
                ref.read(themeProvider.notifier).toggleDarkMode(enabled: val);
              },
              activeColor: AppTheme.primary,
            ),
          ),
          _buildSettingsTile(
            icon: LucideIcons.languages,
            title: 'Language',
            trailing: Text(
              _getLanguageName(ref.watch(localeProvider).languageCode),
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppTheme.primary),
            ),
            onTap: _showLanguageSheet,
          ),
          const SizedBox(height: 24),

          // Account Actions
          const Text(
            'Account',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildSettingsTile(
            icon: LucideIcons.logOut,
            title: 'Log Out',
            iconColor: AppTheme.error,
            textColor: AppTheme.error,
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
          const SizedBox(height: 24),

          // AI & System
          const Text(
            'AI & System',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildSettingsTile(
            icon: LucideIcons.sparkles,
            title: 'Gemini AI Config',
            subtitle: _isLoadingConfig
                ? 'Checking...'
                : _geminiConfigLoaded
                    ? 'Loaded ✓  (managed on server)'
                    : '⚠ Not loaded — contact support',
            iconColor:
                _geminiConfigLoaded ? AppTheme.success : AppTheme.warning,
            trailing: _isLoadingConfig
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(
                    icon: const Icon(LucideIcons.refreshCw, size: 16),
                    onPressed: _loadConfig,
                  ),
          ),
          if (_industry.isNotEmpty)
            _buildSettingsTile(
              icon: LucideIcons.building2,
              title: 'Industry',
              subtitle: _industry,
              onTap: null,
              trailing: const SizedBox.shrink(),
            ),
          const SizedBox(height: 24),

          // About
          const Text(
            'About',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildSettingsTile(
            icon: LucideIcons.info,
            title: 'DigiEntry Mobile',
            subtitle: 'Version 1.0.0 · Built for Indian SMBs',
            onTap: null,
            trailing: const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor ?? AppTheme.textPrimary),
        title: Text(
          title,
          style: TextStyle(color: textColor ?? AppTheme.textPrimary),
        ),
        subtitle: subtitle != null
            ? Text(subtitle,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary))
            : null,
        trailing: trailing ?? const Icon(LucideIcons.chevronRight, size: 20),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'hi':
        return 'हिंदी';
      case 'mr':
        return 'मराठी';
      case 'ta':
        return 'தமிழ்';
      case 'te':
        return 'తెలుగు';
      case 'en':
      default:
        return 'English';
    }
  }

  void _showLanguageSheet() {
    final currentLocale = ref.read(localeProvider);
    final languages = [
      {'code': 'en', 'name': 'English'},
      {'code': 'hi', 'name': 'हिंदी (Hindi)'},
      {'code': 'mr', 'name': 'मराठी (Marathi)'},
      {'code': 'ta', 'name': 'தமிழ் (Tamil)'},
      {'code': 'te', 'name': 'తెలుగు (Telugu)'},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Language',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...languages.map((lang) {
                final isSelected = currentLocale.languageCode == lang['code'];
                return ListTile(
                  title: Text(
                    lang['name']!,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color:
                          isSelected ? AppTheme.primary : AppTheme.textPrimary,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(LucideIcons.check, color: AppTheme.primary)
                      : null,
                  onTap: () {
                    ref
                        .read(localeProvider.notifier)
                        .setLocale(Locale(lang['code']!));
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
