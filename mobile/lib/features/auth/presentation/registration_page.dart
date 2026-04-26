import 'package:mobile/core/widgets/brand_wordmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/shared/widgets/mobile_text_field.dart';
import 'package:mobile/shared/widgets/app_toast.dart';

class RegistrationPage extends ConsumerStatefulWidget {
  const RegistrationPage({super.key});

  @override
  ConsumerState<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends ConsumerState<RegistrationPage> {
  String _username = '';
  String _shopName = '';
  String _password = '';
  String? _selectedIndustry;
  List<Map<String, dynamic>> _industries = [];
  bool _isLoadingIndustries = true;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _fetchIndustries();
  }

  Future<void> _fetchIndustries() async {
    try {
      final repo = AuthRepository();
      var industries = await repo.getIndustries();
      if (industries.isEmpty) {
        industries = [{'id': 'general', 'display': 'General', 'icon': '🏪'}];
      }
      if (mounted) {
        setState(() {
          _industries = industries;
          _selectedIndustry = industries.first['id'] as String;
          _isLoadingIndustries = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _industries = [{'id': 'general', 'display': 'General', 'icon': '🏪'}];
          _selectedIndustry = 'general';
          _isLoadingIndustries = false;
        });
      }
    }
  }

  void _handleRegister() async {
    if (_username.isEmpty || _shopName.isEmpty || _password.isEmpty || _selectedIndustry == null) {
      AppToast.showError(context, 'Please fill all fields', title: 'Error');
      return;
    }

    try {
      await ref.read(authProvider.notifier).register(_username, _password, _shopName, _selectedIndustry!);
    } catch (e) {
      // Error will be shown by auth state listener
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Listen to changes to route on auth success
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuthenticated) {
        context.go('/');
      }
      if (next.error != null && previous?.error != next.error) {
        AppToast.showError(context, next.error!, title: 'Registration Failed');
      }
    });

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: context.textColor),
          onPressed: () => context.pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo placeholder (simulate image)
                Center(
                  child: Image.asset(
                    'assets/images/app_logo_v2.png',
                    height: 100,
                    width: 100,
                  ),
                ),
                const SizedBox(height: 12),
                const Center(child: BrandWordmark(fontSize: 32)),
                const SizedBox(height: 32),

                // Register Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: context.borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.05),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          'Create an Account',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: context.textColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      Text('Shop Name',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14, color: context.textColor)),
                      const SizedBox(height: 8),
                      MobileTextField(
                        initialValue: _shopName,
                        placeholder: 'Enter your shop name',
                        textInputAction: TextInputAction.next,
                        onSave: (val) {
                          setState(() {
                            _shopName = val;
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      Text('User Name',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14, color: context.textColor)),
                      const SizedBox(height: 8),
                      MobileTextField(
                        initialValue: _username,
                        placeholder: 'Choose a User Name',
                        textInputAction: TextInputAction.next,
                        onSave: (val) {
                          setState(() {
                            _username = val;
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      Text('Password',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14, color: context.textColor)),
                      const SizedBox(height: 8),
                      MobileTextField(
                        initialValue: _password,
                        placeholder: 'Choose a password',
                        obscureText: !_isPasswordVisible,
                        textInputAction: TextInputAction.next,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? LucideIcons.eyeOff
                                : LucideIcons.eye,
                            color: context.textSecondaryColor,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                        onSave: (val) {
                          setState(() {
                            _password = val;
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      Text('Industry',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14, color: context.textColor)),
                      const SizedBox(height: 8),
                      
                      _isLoadingIndustries 
                        ? const Center(child: Padding(
                           padding: EdgeInsets.all(8.0),
                           child: CircularProgressIndicator(),
                        ))
                        : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: context.borderColor),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedIndustry,
                              isExpanded: true,
                              icon: const Icon(LucideIcons.chevronDown),
                              hint: Text('Select Industry', style: TextStyle(color: context.textSecondaryColor)),
                              dropdownColor: context.surfaceColor,
                              items: _industries.map((Map<String, dynamic> industry) {
                                return DropdownMenuItem<String>(
                                  value: industry['id'] as String,
                                  child: Row(
                                    children: [
                                      Text('${industry['icon']} '),
                                      Text(industry['display'] as String, style: TextStyle(color: context.textColor)),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedIndustry = newValue;
                                });
                              },
                            ),
                          ),
                        ),

                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: authState.isLoading ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: authState.isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 3),
                                )
                              : const Text(
                                  'Sign Up',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.lock, color: context.successColor, size: 14),
                    const SizedBox(width: 6),
                    Text('Your data is safe & secure',
                        style: TextStyle(
                            color: context.textSecondaryColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
