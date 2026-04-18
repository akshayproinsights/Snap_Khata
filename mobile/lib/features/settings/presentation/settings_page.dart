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
import 'package:fl_chart/fl_chart.dart';

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
  String _usageFilter = '1 Week';

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
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textSecondary,
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
              border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkBorder
                      : AppTheme.border),
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
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.textSecondary,
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

          // Usage Stats
          _buildUsageChart(context),
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
              activeThumbColor: AppTheme.primary,
            ),
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
        border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkBorder
                : AppTheme.border),
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
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textSecondary))
            : null,
        trailing: trailing ?? const Icon(LucideIcons.chevronRight, size: 20),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildUsageChart(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Mock data based on filter
    List<int> customerOrders;
    List<int> supplierOrders;
    List<String> xLabels;
    int maxX;
    double maxY;

    switch (_usageFilter) {
      case '1 Month':
        customerOrders = [45, 52, 60, 55];
        supplierOrders = [20, 25, 30, 28];
        xLabels = ['Week 1', 'Week 2', 'Week 3', 'Week 4'];
        maxX = 3;
        maxY = 70;
        break;
      case 'All Time':
        customerOrders = [120, 150, 180, 210, 250, 300];
        supplierOrders = [50, 65, 80, 110, 140, 180];
        xLabels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
        maxX = 5;
        maxY = 350;
        break;
      case '1 Week':
      default:
        customerOrders = [12, 15, 14, 22, 18, 28, 30];
        supplierOrders = [5, 8, 6, 11, 9, 14, 18];
        xLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        maxX = 6;
        maxY = 35;
        break;
    }

    final totalCustomer = customerOrders.reduce((a, b) => a + b);
    final totalSupplier = supplierOrders.reduce((a, b) => a + b);
    final totalProcessed = totalCustomer + totalSupplier;

    final customerColor = const Color(0xFF0EA5E9); // Modern Blue
    final supplierColor = const Color(0xFF8B5CF6); // Modern Purple

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Orders Processed',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Total: $totalProcessed',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['1 Week', '1 Month', 'All Time'].map((filter) {
                final isSelected = _usageFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(filter, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    showCheckmark: false,
                    selectedColor: AppTheme.primary.withValues(alpha: 0.1),
                    labelStyle: TextStyle(
                      color: isSelected ? AppTheme.primary : (isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    side: BorderSide(
                      color: isSelected ? AppTheme.primary : (isDark ? AppTheme.darkBorder : AppTheme.border),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _usageFilter = filter;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          // Legends
          Row(
            children: [
              _buildLegendItem('Customers ($totalCustomer)', customerColor),
              const SizedBox(width: 16),
              _buildLegendItem('Suppliers ($totalSupplier)', supplierColor),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4 > 0 ? maxY / 4 : 10,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDark ? AppTheme.darkBorder : AppTheme.border,
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        const style = TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondary,
                        );
                        final index = value.toInt();
                        Widget text;
                        if (index >= 0 && index < xLabels.length) {
                          if (_usageFilter == '1 Week') {
                            if (index % 2 == 0) {
                              text = Text(xLabels[index], style: style);
                            } else {
                              text = const Text('', style: style);
                            }
                          } else {
                            text = Text(xLabels[index], style: style);
                          }
                        } else {
                          text = const Text('', style: style);
                        }
                        
                        return SideTitleWidget(
                          meta: meta,
                          child: text,
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: maxX.toDouble(),
                minY: 0, // start from 0 is clearer usually, wait previously was 0
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: customerOrders.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.toDouble())).toList(),
                    isCurved: true,
                    color: customerColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: customerColor.withValues(alpha: 0.1),
                    ),
                  ),
                  LineChartBarData(
                    spots: supplierOrders.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.toDouble())).toList(),
                    isCurved: true,
                    color: supplierColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: supplierColor.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
