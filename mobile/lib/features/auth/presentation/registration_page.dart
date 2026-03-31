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

  @override
  void initState() {
    super.initState();
    _fetchIndustries();
  }

  Future<void> _fetchIndustries() async {
    try {
      final repo = AuthRepository();
      final industries = await repo.getIndustries();
      if (mounted) {
        setState(() {
          _industries = industries;
          if (industries.isNotEmpty) {
            _selectedIndustry = industries.first['id'] as String;
          }
          _isLoadingIndustries = false;
        });
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Failed to load industries', title: 'Error');
        setState(() {
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
        context.go('/dashboard');
      }
      if (next.error != null && previous?.error != next.error) {
        AppToast.showError(context, next.error!, title: 'Registration Failed');
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppTheme.textPrimary),
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
                  child: Container(
                    height: 80,
                    width: 200,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'SnapKhata',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Register Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: Text(
                          'Create an Account',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      const Text('Shop Name',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
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

                      const Text('User ID',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 8),
                      MobileTextField(
                        initialValue: _username,
                        placeholder: 'Choose a User ID',
                        textInputAction: TextInputAction.next,
                        onSave: (val) {
                          setState(() {
                            _username = val;
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      const Text('Password',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 8),
                      MobileTextField(
                        initialValue: _password,
                        placeholder: 'Choose a password',
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        onSave: (val) {
                          setState(() {
                            _password = val;
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      const Text('Industry',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 8),
                      
                      _isLoadingIndustries 
                        ? const Center(child: Padding(
                           padding: EdgeInsets.all(8.0),
                           child: CircularProgressIndicator(),
                        ))
                        : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.border),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedIndustry,
                              isExpanded: true,
                              icon: const Icon(LucideIcons.chevronDown),
                              hint: const Text('Select Industry'),
                              items: _industries.map((Map<String, dynamic> industry) {
                                return DropdownMenuItem<String>(
                                  value: industry['id'] as String,
                                  child: Row(
                                    children: [
                                      Text('${industry['icon']} '),
                                      Text(industry['display'] as String),
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
                            backgroundColor: AppTheme.primary,
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
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.lock, color: AppTheme.success, size: 14),
                    SizedBox(width: 6),
                    Text('Your data is safe & secure',
                        style: TextStyle(
                            color: AppTheme.textSecondary,
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
