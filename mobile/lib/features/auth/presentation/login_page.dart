import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/google_signin_button.dart';
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
  bool _isPasswordVisible = false;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleAuthSubscription;

  @override
  void initState() {
    super.initState();
    _initGoogleSignIn();
  }

  Future<void> _initGoogleSignIn() async {
    // Initialize the GoogleSignIn singleton (idempotent — safe to call after
    // first time due to the _googleSignInInitialized guard in auth_provider.dart).
    await ensureGoogleSignInInitialized();
    // Listen to the auth events emitted by the GSI button (web-only approach).
    _googleAuthSubscription = GoogleSignIn.instance.authenticationEvents
        .listen((GoogleSignInAuthenticationEvent event) {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        // User successfully signed in via the Google GSI button.
        ref
            .read(authProvider.notifier)
            .handleGoogleSignInAccount(event.user);
      }
    });
  }

  @override
  void dispose() {
    _googleAuthSubscription?.cancel();
    super.dispose();
  }

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
                              constraints: const BoxConstraints(maxHeight: 200),
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
                                'Welcome Back',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: context.textColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Google Sign-In Button (Official GSI button for web)
                            // On web, authenticate() is NOT supported.
                            // On mobile, custom button triggers GoogleSignIn.instance.signIn().
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: renderGoogleSignInButton(
                                onPressed: () async {
                                  try {
                                    final googleUser = await GoogleSignIn.instance.authenticate();
                                    await ref
                                        .read(authProvider.notifier)
                                        .handleGoogleSignInAccount(googleUser);
                                  } catch (e) {
                                    if (e is GoogleSignInException &&
                                        e.code == GoogleSignInExceptionCode.canceled) {
                                      // User canceled the sign-in flow, ignore.
                                      return;
                                    }
                                    if (context.mounted) {
                                      AppToast.showError(
                                        context,
                                        'Google Sign-In failed: $e',
                                        title: 'Authentication Error',
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Create an Account
                            Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("New user? ", style: TextStyle(color: context.textColor, fontSize: 13)),
                                  GestureDetector(
                                    onTap: () => context.push('/register'),
                                    child: Text(
                                      "Create an Account",
                                      style: TextStyle(
                                          color: context.primaryColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // OR Divider
                            Row(
                              children: [
                                Expanded(child: Divider(color: context.borderColor)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    'OR',
                                    style: TextStyle(
                                      color: context.textColor.withValues(alpha: 0.5),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: context.borderColor)),
                              ],
                            ),
                            const SizedBox(height: 24),

                            Text('User Name',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13, color: context.textColor)),
                            const SizedBox(height: 6),
                            MobileTextField(
                              initialValue: _username,
                              placeholder: 'Enter your User Name',
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
                              obscureText: !_isPasswordVisible,
                              textInputAction: TextInputAction.done,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                  color: context.textColor.withValues(alpha: 0.5),
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                              onSubmitted: (_) => _handleLogin(),
                              onSave: (val) {
                                setState(() {
                                  _password = val;
                                });
                              },
                            ),
                            const SizedBox(height: 8),

                             Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => const ChangePasswordDialog(),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    color: context.primaryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
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

                      const SizedBox(height: 24),

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
                          Text('Made in India',
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

class ChangePasswordDialog extends ConsumerStatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  ConsumerState<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  String _username = '';
  String _currentPassword = '';
  String _newPassword = '';
  String _confirmPassword = '';
  bool _isLoading = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (_newPassword != _confirmPassword) {
      AppToast.showError(context, 'New passwords do not match.', title: 'Validation Error');
      return;
    }

    if (_newPassword.length < 6) {
      AppToast.showError(context, 'Password must be at least 6 characters.', title: 'Validation Error');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(authProvider.notifier).changePassword(
        _username,
        _currentPassword,
        _newPassword,
      );
      if (mounted) {
        AppToast.showSuccess(context, 'Password updated successfully!', title: 'Success');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, e.toString(), title: 'Error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Change Password',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: context.textColor,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'User Name',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: context.textColor),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    decoration: InputDecoration(
                      hintText: 'Enter your User Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                    onSaved: (val) => _username = val ?? '',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Current Password',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: context.textColor),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    obscureText: !_showCurrent,
                    decoration: InputDecoration(
                      hintText: 'Enter current password',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      suffixIcon: IconButton(
                        icon: Icon(_showCurrent ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _showCurrent = !_showCurrent),
                      ),
                    ),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    onSaved: (val) => _currentPassword = val ?? '',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'New Password',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: context.textColor),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    obscureText: !_showNew,
                    decoration: InputDecoration(
                      hintText: 'Enter new password',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      suffixIcon: IconButton(
                        icon: Icon(_showNew ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _showNew = !_showNew),
                      ),
                    ),
                    validator: (val) => val == null || val.length < 6 ? 'Password must be >= 6 characters' : null,
                    onSaved: (val) => _newPassword = val ?? '',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Confirm New Password',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: context.textColor),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    obscureText: !_showConfirm,
                    decoration: InputDecoration(
                      hintText: 'Re-enter new password',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      suffixIcon: IconButton(
                        icon: Icon(_showConfirm ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _showConfirm = !_showConfirm),
                      ),
                    ),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    onSaved: (val) => _confirmPassword = val ?? '',
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Update', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
