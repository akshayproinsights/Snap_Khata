import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/theme/theme_provider.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/shared/widgets/mobile_text_field.dart';
import 'package:mobile/shared/widgets/app_toast.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/settings/presentation/providers/shop_provider.dart';
import 'package:mobile/features/settings/domain/models/shop_profile.dart';

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
  final bool _isLoadingProfile = false;

  @override
  void initState() {
    super.initState();
    _loadShopDetails();
  }

  /// Load from provider
  Future<void> _loadShopDetails() async {
    final profile = ref.read(shopProvider);
    setState(() {
      _shopName = profile.name;
      _shopAddress = profile.address;
      _shopPhone = profile.phone;
      _shopGst = profile.gst;
    });
    
    // Trigger a sync in the background
    ref.read(shopProvider.notifier).syncWithBackend();
  }

  /// Save using provider
  Future<void> _saveShopDetails() async {
    final newProfile = ShopProfile(
      name: _shopName,
      address: _shopAddress,
      phone: _shopPhone,
      gst: _shopGst,
    );
    await ref.read(shopProvider.notifier).updateProfile(newProfile);
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
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
              Text(
                'This info appears on your invoices & syncs across devices',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13),
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
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
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      if (_shopName.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            _isLoadingProfile ? 'Syncing...' : _shopName,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Usage Stats (Moved to separate page)
          const SizedBox(height: 8),

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
              activeThumbColor: AppTheme.primary,
            ),
          ),
          _buildSettingsTile(
            icon: LucideIcons.barChart2,
            title: 'Orders Processed',
            subtitle: 'View real usage metrics',
            onTap: () {
              context.push('/usage-stats');
            },
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

          // About
          const Text(
            'About',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildSettingsTile(
            icon: LucideIcons.info,
            title: 'SnapKhata Mobile',
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ListTile(
        leading: Icon(icon,
            color: iconColor ?? Theme.of(context).colorScheme.onSurface),
        title: Text(
          title,
          style: TextStyle(
              color: textColor ?? Theme.of(context).colorScheme.onSurface),
        ),
        subtitle: subtitle != null
            ? Text(subtitle,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant))
            : null,
        trailing: trailing ?? const Icon(LucideIcons.chevronRight, size: 20),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

}
