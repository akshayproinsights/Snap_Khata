import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/theme/theme_provider.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/shared/widgets/mobile_text_field.dart';
import 'package:mobile/shared/widgets/app_toast.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/settings/presentation/providers/shop_provider.dart';
import 'package:mobile/features/settings/domain/models/shop_profile.dart';
import 'package:mobile/core/widgets/brand_wordmark.dart';
import 'package:mobile/core/localization/locale_provider.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/core/network/api_client.dart';

class SettingsPage extends ConsumerStatefulWidget {
  final bool openShopDetails;

  const SettingsPage({super.key, this.openShopDetails = false});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String _shopName = '';
  String _shopAddress = '';
  String _shopPhone = '';
  String _shopGst = '';
  String _shopUpiId = '';
  String _shopLogoUrl = '';
  String _customTerms = '';
  String _whatsappCustomNote = '';
  String _shopType = 'general';
  final bool _isLoadingProfile = false;
  bool _isUploadingLogo = false;

  @override
  void initState() {
    super.initState();
    _loadShopDetails();
    // Auto-open shop details sheet if requested
    if (widget.openShopDetails) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showShopDetailsSheet();
      });
    }
  }

  /// Load initial values from provider (may be empty before sync completes).
  /// ref.listen in build() will update these fields once backend sync finishes.
  Future<void> _loadShopDetails() async {
    final profile = ref.read(shopProvider);
    if (!mounted) return;
    setState(() {
      _shopName = profile.name;
      _shopAddress = profile.address;
      _shopPhone = profile.phone;
      _shopGst = profile.gst;
      _shopUpiId = profile.upiId;
      _shopLogoUrl = profile.logoUrl;
      _customTerms = profile.customTerms;
      _whatsappCustomNote = profile.whatsappCustomNote;
      _shopType = profile.shopType;
    });
  }

  /// Save using provider
  Future<void> _saveShopDetails() async {
    final newProfile = ShopProfile(
      name: _shopName,
      address: _shopAddress,
      phone: _shopPhone,
      gst: _shopGst,
      upiId: _shopUpiId,
      logoUrl: _shopLogoUrl,
      customTerms: _customTerms,
      whatsappCustomNote: _whatsappCustomNote,
      shopType: _shopType,
    );
    await ref.read(shopProvider.notifier).updateProfile(newProfile);
  }

  // ── Logo image helpers ───────────────────────────────────────────────────

  /// Shows a bottom sheet to pick the logo source (gallery / camera)
  Future<String?> _pickAndUploadLogo(StateSetter setSheetState) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose Logo Source',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.textColor,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(LucideIcons.image, color: context.primaryColor),
              title: Text('Choose from Gallery',
                  style: TextStyle(color: context.textColor)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            ListTile(
              leading: Icon(LucideIcons.camera, color: context.primaryColor),
              title: Text('Take a Photo',
                  style: TextStyle(color: context.textColor)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return null;

    return _pickLogoFromSource(source, setSheetState);
  }

  /// Picks from a specific [source], uploads to R2, then immediately persists
  /// the returned URL to the backend so it is available on receipts/invoices
  /// without requiring the user to press "Save & Sync".
  Future<String?> _pickLogoFromSource(
      ImageSource source, StateSetter setSheetState) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked == null) return null;

    setSheetState(() => _isUploadingLogo = true);

    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last.toLowerCase();
      final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: 'shop_logo.$ext',
          contentType: DioMediaType.parse(contentType),
        ),
      });

      final response = await ApiClient().dio.post(
        '/api/shop-profile/upload-logo',
        data: formData,
      );

      final url = response.data['logo_url'] as String? ?? '';
      if (url.isEmpty) return null;

      // ── Immediately persist the new logo URL so it shows on invoices ──────
      // Build a merged profile with the new URL and push it to the backend.
      // This ensures shop_logo_url is in user_profiles for the public receipt
      // endpoint even if the user dismisses the sheet without pressing Save.
      final currentProfile = ref.read(shopProvider);
      final updatedProfile = ShopProfile(
        name: currentProfile.name,
        address: currentProfile.address,
        phone: currentProfile.phone,
        gst: currentProfile.gst,
        upiId: currentProfile.upiId,
        logoUrl: url,
        customTerms: currentProfile.customTerms,
        whatsappCustomNote: currentProfile.whatsappCustomNote,
        shopType: currentProfile.shopType,
      );
      // Fire-and-forget: update provider + backend; don't block the UI.
      unawaited(ref.read(shopProvider.notifier).updateProfile(updatedProfile));

      return url;
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Failed to upload logo: $e');
      }
      return null;
    } finally {
      setSheetState(() => _isUploadingLogo = false);
    }
  }

  /// Renders an initials box to use as a logo placeholder.
  Widget _logoPlaceholder(BuildContext ctx, String shopName) {
    return Container(
      height: 80,
      width: 80,
      color: ctx.primaryColor.withValues(alpha: 0.08),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.imagePlus,
                color: ctx.primaryColor.withValues(alpha: 0.6), size: 22),
            const SizedBox(height: 4),
            Text(
              shopName.isNotEmpty ? shopName[0].toUpperCase() : 'S',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ctx.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Renders a compact action button for gallery/camera logo picking.
  Widget _logoActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: enabled
              ? context.primaryColor.withValues(alpha: 0.08)
              : context.borderColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled
                ? context.primaryColor.withValues(alpha: 0.25)
                : context.borderColor,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 16,
                color: enabled
                    ? context.primaryColor
                    : context.textSecondaryColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: enabled
                    ? context.primaryColor
                    : context.textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showShopDetailsSheet() {
    // Local copies editable inside the sheet
    String tempName = _shopName;
    String tempAddress = _shopAddress;
    String tempPhone = _shopPhone;
    String tempGst = _shopGst;
    String tempUpiId = _shopUpiId;
    String tempLogoUrl = _shopLogoUrl;
    String tempCustomTerms = _customTerms;
    String tempWhatsAppNote = _whatsappCustomNote;
    String tempShopType = _shopType;
    bool isAutofilling = false;

    void pickAndAutofillFromReceipt(StateSetter setSheetState) async {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scan Receipt / Business Card',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.textColor,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(LucideIcons.image, color: context.primaryColor),
                title: Text('Choose from Gallery',
                    style: TextStyle(color: context.textColor)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              ListTile(
                leading: Icon(LucideIcons.camera, color: context.primaryColor),
                title: Text('Take a Photo',
                    style: TextStyle(color: context.textColor)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
      if (source == null) return;

      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked == null) return;

      setSheetState(() => isAutofilling = true);

      try {
        final bytes = await picked.readAsBytes();
        final ext = picked.name.split('.').last.toLowerCase();
        final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';

        final formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(
            bytes,
            filename: 'shop_receipt.$ext',
            contentType: DioMediaType.parse(contentType),
          ),
        });

        final response = await ApiClient().dio.post(
          '/api/shop-profile/autofill-from-receipt',
          data: formData,
        );

        final data = response.data as Map<String, dynamic>;
        
        setSheetState(() {
          tempName = data['shop_name'] as String? ?? tempName;
          tempAddress = data['shop_address'] as String? ?? tempAddress;
          tempPhone = data['shop_phone'] as String? ?? tempPhone;
          tempGst = data['shop_gst'] as String? ?? tempGst;
          tempUpiId = data['shop_upi_id'] as String? ?? tempUpiId;
          tempShopType = data['shop_type'] as String? ?? tempShopType;
        });

        if (mounted) {
          AppToast.showSuccess(context, 'Autofilled successfully! Please review & save.');
        }
      } catch (e) {
        if (mounted) {
          AppToast.showError(context, 'Failed to extract receipt: $e');
        }
      } finally {
        setSheetState(() => isAutofilling = false);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: context.backgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
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
                      color: context.textSecondaryColor,
                      fontSize: 13),
                ),
                const SizedBox(height: 16),
                if (isAutofilling)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: context.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.primaryColor.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'AI extracting shop details...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () => pickAndAutofillFromReceipt(setSheetState),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: context.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: context.primaryColor.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.sparkles, color: context.primaryColor, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Autofill from Receipt / Card (AI Scan)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: context.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MobileTextField(
                          initialValue: tempName,
                          placeholder: 'Shop Name',
                          onSave: (val) {
                            setSheetState(() => tempName = val);
                          },
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
                        const SizedBox(height: 12),
                        MobileTextField(
                          initialValue: tempUpiId,
                          placeholder: 'UPI ID (Optional)',
                          onSave: (val) => tempUpiId = val,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'UPI ID is shown as Scan-to-Pay QR on your invoice',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.textSecondaryColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // ── Shop Logo ─────────────────────────────────────────
                        Text(
                          'Shop Logo',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: context.textColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        StatefulBuilder(
                          builder: (context, setLogoState) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // ── Logo preview / placeholder ────────────────
                                GestureDetector(
                                  onTap: _isUploadingLogo
                                      ? null
                                      : () async {
                                          final url =
                                              await _pickAndUploadLogo((fn) {
                                            setLogoState(fn);
                                            setSheetState(fn);
                                          });
                                          if (url != null) {
                                            setLogoState(() {
                                              tempLogoUrl = url;
                                            });
                                            setSheetState(() {
                                              tempLogoUrl = url;
                                            });
                                          }
                                        },
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 200),
                                    height: 80,
                                    width: 80,
                                    decoration: BoxDecoration(
                                      color: context.primaryColor
                                          .withValues(alpha: 0.08),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border: Border.all(
                                        color: tempLogoUrl.isNotEmpty
                                            ? context.primaryColor
                                                .withValues(alpha: 0.5)
                                            : context.borderColor,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: _isUploadingLogo
                                        ? Center(
                                            child: SizedBox(
                                              width: 24,
                                              height: 24,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: context.primaryColor,
                                              ),
                                            ),
                                          )
                                        : ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            child: tempLogoUrl.isNotEmpty
                                                ? Image.network(
                                                    tempLogoUrl,
                                                    height: 80,
                                                    width: 80,
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (_, __, ___) =>
                                                            _logoPlaceholder(
                                                                context,
                                                                tempName),
                                                  )
                                                : _logoPlaceholder(
                                                    context, tempName),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // ── Action buttons ────────────────────────────
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _logoActionButton(
                                        context: context,
                                        icon: LucideIcons.image,
                                        label: 'Choose from Gallery',
                                        enabled: !_isUploadingLogo,
                                        onTap: () async {
                                          final url =
                                              await _pickLogoFromSource(
                                                  ImageSource.gallery,
                                                  setSheetState);
                                          if (url != null) {
                                            setLogoState(() =>
                                                tempLogoUrl = url);
                                            setSheetState(() =>
                                                tempLogoUrl = url);
                                          }
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                      _logoActionButton(
                                        context: context,
                                        icon: LucideIcons.camera,
                                        label: 'Take a Photo',
                                        enabled: !_isUploadingLogo,
                                        onTap: () async {
                                          final url =
                                              await _pickLogoFromSource(
                                                  ImageSource.camera,
                                                  setSheetState);
                                          if (url != null) {
                                            setLogoState(() =>
                                                tempLogoUrl = url);
                                            setSheetState(() =>
                                                tempLogoUrl = url);
                                          }
                                        },
                                      ),
                                      if (tempLogoUrl.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        GestureDetector(
                                          onTap: () {
                                            setLogoState(
                                                () => tempLogoUrl = '');
                                            setSheetState(
                                                () => tempLogoUrl = '');
                                          },
                                          child: Text(
                                            'Remove logo',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: context.errorColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        // ── Custom Terms ─────────────────────────────────────
                        Text(
                          'Terms & Conditions on Invoice',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: context.textColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: tempCustomTerms,
                          maxLines: 3,
                          style: TextStyle(color: context.textColor, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'e.g. Goods once sold will not be returned. All disputes subject to local jurisdiction.',
                            hintStyle: TextStyle(
                              color: context.textSecondaryColor.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                            filled: true,
                            fillColor: context.isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          ),
                          onChanged: (val) => setSheetState(() => tempCustomTerms = val),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'This replaces the default "Thank you for your business" on invoices.',
                          style: TextStyle(fontSize: 11, color: context.textSecondaryColor),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'WhatsApp Bill/Reminder Note',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: context.textColor,
                              letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: tempWhatsAppNote,
                          maxLines: 2,
                          style: TextStyle(color: context.textColor),
                          decoration: InputDecoration(
                            hintText: 'e.g. Please collect clothes after 4 days.',
                            hintStyle: TextStyle(color: context.textSecondaryColor.withValues(alpha: 0.5)),
                            filled: true,
                            fillColor: context.isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onChanged: (val) {
                            setSheetState(() {
                              tempWhatsAppNote = val;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        // ── Shop Type Selector ────────────────────────────────
                        Text(
                          'Shop Type',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: context.textColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (final option in [
                              ('general', 'General 🏪'),
                              ('laundry', 'Laundry 👕'),
                            ])
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setSheetState(
                                    () => tempShopType = option.$1,
                                  ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    margin: EdgeInsets.only(
                                      right: option.$1 == 'general' ? 8 : 0,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: tempShopType == option.$1
                                          ? context.primaryColor
                                          : (context.isDark
                                                ? Colors.grey.shade900
                                                : Colors.grey.shade100),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: tempShopType == option.$1
                                            ? context.primaryColor
                                            : context.borderColor,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        option.$2,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: tempShopType == option.$1
                                              ? Colors.white
                                              : context.textColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'PREVIEW',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: context.textSecondaryColor,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.isDark ? const Color(0xFF054735) : const Color(0xFFDCF8C6),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            'Hi Customer,\n'
                            'Your order from *${tempName.isNotEmpty ? tempName.trim() : 'Our Shop'}* is ready. 📝\n\n'
                            '⚠️ *Amount Due: ₹450*'
                            '${tempWhatsAppNote.trim().isNotEmpty ? '\n\n👉 *Note:* ${tempWhatsAppNote.trim()}' : ''}\n\n'
                            'Thank you! 🙏\n'
                            '— *${tempName.isNotEmpty ? tempName.trim() : 'Our Shop'}*',
                            style: TextStyle(
                              color: context.isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF0D0D0D),
                              fontSize: 12,
                              height: 1.55,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      setState(() {
                        _shopName = tempName;
                        _shopAddress = tempAddress;
                        _shopPhone = tempPhone;
                        _shopGst = tempGst;
                        _shopUpiId = tempUpiId;
                        _shopLogoUrl = tempLogoUrl;
                        _customTerms = tempCustomTerms;
                        _whatsappCustomNote = tempWhatsAppNote;
                        _shopType = tempShopType;
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
                      backgroundColor: context.primaryColor,
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
      ),
    );
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: context.backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)?.selectLanguage ?? 'Select Language / भाषा निवडा',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Text('🇺🇸', style: TextStyle(fontSize: 24)),
              title: const Text('English'),
              trailing: ref.watch(localeProvider).languageCode == 'en'
                  ? Icon(LucideIcons.checkCircle2, color: context.primaryColor)
                  : null,
              onTap: () {
                ref.read(localeProvider.notifier).setLocale(const Locale('en'));
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Text('🇮🇳', style: TextStyle(fontSize: 24)),
              title: const Text('मराठी (Marathi)'),
              trailing: ref.watch(localeProvider).languageCode == 'mr'
                  ? Icon(LucideIcons.checkCircle2, color: context.primaryColor)
                  : null,
              onTap: () {
                ref.read(localeProvider.notifier).setLocale(const Locale('mr'));
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep local fields in sync with the provider — fires when background
    // syncWithBackend() completes after the page first opens.
    ref.listen<ShopProfile>(shopProvider, (prev, next) {
      if (!mounted) return;
      setState(() {
        _shopName           = next.name;
        _shopAddress        = next.address;
        _shopPhone          = next.phone;
        _shopGst            = next.gst;
        _shopUpiId          = next.upiId;
        _shopLogoUrl        = next.logoUrl;
        _customTerms        = next.customTerms;
        _whatsappCustomNote = next.whatsappCustomNote;
        _shopType           = next.shopType;
      });
    });

    final userState = ref.watch(authProvider);
    final String userName =
        userState.user?.name ?? userState.user?.username ?? 'User';
    final String userEmail = userState.user?.email ?? '';

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)?.settings ?? 'SETTINGS',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: context.textColor,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Profile Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: context.premiumShadow,
              border: Border.all(
                color: context.borderColor,
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: context.primaryColor.withValues(alpha: 0.1),
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: context.primaryColor,
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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: context.textColor,
                        ),
                      ),
                      if (userEmail.isNotEmpty)
                        Text(
                          userEmail,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textSecondaryColor,
                          ),
                        ),
                      if (_shopName.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            _isLoadingProfile ? 'Syncing...' : _shopName,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textSecondaryColor,
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
          Text(
            AppLocalizations.of(context)?.preferences ?? 'Preferences',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textColor),
          ),
          const SizedBox(height: 12),
          _buildSettingsTile(
            icon: LucideIcons.languages,
            title: AppLocalizations.of(context)?.language ?? 'Language / भाषा',
            subtitle: ref.watch(localeProvider).languageCode == 'mr'
                ? 'मराठी (Marathi)'
                : 'English',
            onTap: _showLanguageSelector,
          ),
          _buildSettingsTile(
            icon: LucideIcons.store,
            title: AppLocalizations.of(context)?.shopDetails ?? 'Shop Details',
            subtitle: _shopName.isNotEmpty ? _shopName : 'Tap to set up',
            onTap: _showShopDetailsSheet,
          ),
          _buildSettingsTile(
            icon: LucideIcons.tag,
            title: 'My Item Catalogue',
            subtitle: 'Manage items and prices',
            onTap: () {
              context.push('/item-catalogue');
            },
          ),
          _buildSettingsTile(
            icon: LucideIcons.moon,
            title: AppLocalizations.of(context)?.darkMode ?? 'Dark Mode',
            trailing: Switch(
              value: ref.watch(themeProvider) == ThemeMode.dark,
              onChanged: (val) {
                ref.read(themeProvider.notifier).toggleDarkMode(enabled: val);
              },
              activeThumbColor: context.primaryColor,
            ),
          ),
          _buildSettingsTile(
            icon: LucideIcons.barChart2,
            title: AppLocalizations.of(context)?.ordersProcessed ?? 'Orders Processed',
            subtitle: 'View real usage metrics',
            onTap: () {
              context.push('/usage-stats');
            },
          ),
          _buildSettingsTile(
            icon: LucideIcons.lineChart,
            title: 'Dashboard Analytics',
            subtitle: 'View sales and purchases',
            onTap: () {
              context.push('/analytics');
            },
          ),

          const SizedBox(height: 24),

          // Account Actions
          Text(
            AppLocalizations.of(context)?.account ?? 'Account',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textColor),
          ),
          const SizedBox(height: 12),
          _buildSettingsTile(
            icon: LucideIcons.logOut,
            title: AppLocalizations.of(context)?.logOut ?? 'Log Out',
            iconColor: context.errorColor,
            textColor: context.errorColor,
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
          const SizedBox(height: 24),

          // About
          Text(
            AppLocalizations.of(context)?.about ?? 'About',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textColor),
          ),
          const SizedBox(height: 12),
          _buildSettingsTile(
            icon: LucideIcons.info,
            titleWidget: const BrandWordmark(fontSize: 18),
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
    String? title,
    Widget? titleWidget,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: context.premiumShadow,
        border: Border.all(
          color: context.borderColor,
          width: 0.5,
        ),
      ),
      child: ListTile(
        leading: Icon(icon,
            color: iconColor ?? context.textColor),
        title: titleWidget ?? Text(
          title ?? '',
          style: TextStyle(
              color: textColor ?? context.textColor),
        ),
        subtitle: subtitle != null
            ? Text(subtitle,
                style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondaryColor))
            : null,
        trailing: trailing ?? const Icon(LucideIcons.chevronRight, size: 20),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

}
