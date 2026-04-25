import re

with open('/root/Snap_Khata/mobile/lib/features/auth/presentation/login_page.dart', 'r') as f:
    content = f.read()

# Replace everything from "return Scaffold(" to the end of the file.
pattern = r"return Scaffold\(.*"
replacement = """return Scaffold(
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
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 240),
                          child: Image.asset(
                            'assets/images/login_hero.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              // Fallback placeholder while the user uploads the image
                              return Container(
                                height: 180,
                                width: 220,
                                decoration: BoxDecoration(
                                  color: context.primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Text('SnapKhata',
                                    style: TextStyle(color: context.primaryColor, fontSize: 28, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              );
                            },
                          ),
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
                                'Login to Your Account',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: context.textColor,
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
"""

new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)
with open('/root/Snap_Khata/mobile/lib/features/auth/presentation/login_page.dart', 'w') as f:
    f.write(new_content)
