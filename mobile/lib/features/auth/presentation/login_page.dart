import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/shared/widgets/mobile_text_field.dart';
import 'package:mobile/shared/widgets/app_toast.dart';
import 'package:mobile/core/widgets/brand_wordmark.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  String _username = '';
  String _password = '';

  void _handleLogin() async {
    if (_username.isEmpty || _password.isEmpty) return;

    await ref.read(authProvider.notifier).login(_username, _password);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Listen to changes to route on auth success
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuthenticated) {
        context.go('/');
      }
      if (next.error != null) {
        AppToast.showError(context, next.error!, title: 'Login Failed');
      }
    });

    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Hero Image (Image 2)
                      Center(
                        child: Column(
                          children: [
                            const BrandWordmark(fontSize: 32),
                            const SizedBox(height: 16),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 400),
                              child: Image.asset(
                                'assets/images/login_hero_v2.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Login Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: context.surfaceColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: context.borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.05),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Text(
                                'SMART DIGITAL MUNIM',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: context.textColor.withValues(alpha: 0.6),
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            Text('User ID',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13, color: context.textColor)),
                            const SizedBox(height: 6),
                            MobileTextField(
                              initialValue: _username,
                              placeholder: 'Enter your User ID',
                              textInputAction: TextInputAction.next,
                              onSave: (val) {
                                setState(() {
                                  _username = val;
                                });
                              },
                            ),
                            const SizedBox(height: 16),

                            Text('Password',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13, color: context.textColor)),
                            const SizedBox(height: 6),
                            MobileTextField(
                              initialValue: _password,
                              placeholder: 'Enter your password',
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _handleLogin(),
                              onSave: (val) {
                                setState(() {
                                  _password = val;
                                });
                              },
                            ),
                            const SizedBox(height: 24),

                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: authState.isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: context.primaryColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: authState.isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            color: Colors.white, strokeWidth: 3),
                                      )
                                    : const Text(
                                        'Login',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () => context.push('/register'),
                          child: Text('New user? Sign Up here', 
                            style: TextStyle(color: context.primaryColor, fontWeight: FontWeight.w600, fontSize: 14)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Trust Badge & Footer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(LucideIcons.shieldCheck,
                              color: AppTheme.success, size: 14),
                          const SizedBox(width: 4),
                          Text('100% Secure',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 11, color: context.textColor)),
                          const SizedBox(width: 8),
                          Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                  color: context.borderColor, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text('🇮🇳 Made in India',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 11, color: context.textColor)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
