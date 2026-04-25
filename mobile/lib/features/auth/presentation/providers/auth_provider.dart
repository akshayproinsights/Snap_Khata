import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';
import 'package:mobile/features/auth/domain/models/user_model.dart';
import 'package:mobile/core/routing/app_router.dart';

// Provides the AuthRepository instance
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

// Represents the state of authentication
class AuthState {
  final User? user;
  final String? token;
  final bool isLoading;
  final String? error;

  AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => token != null && user != null;

  AuthState copyWith({
    User? user,
    String? token,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      error: error, // Allow nulling out the error
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    
    // Register global 401 handler
    ApiClient.onUnauthorized = () {
      if (state.isAuthenticated) {
        logout();
      }
      // Ensure we navigate to the login page when unauthorized
      AppRouter.router.go('/login');
    };
    
    Future.microtask(() => _checkInitialAuth());
    return AuthState(isLoading: true);
  }

  Future<void> _checkInitialAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      // CRITICAL: Also read the stored username to detect cross-user session issues
      final storedUsername = prefs.getString('auth_username');

      if (token != null) {
        state = state.copyWith(token: token);
        // Always verify token with server (catches stale/wrong-user tokens)
        final user = await _repository.getMe();

        // CRITICAL SAFETY CHECK: If stored username doesn't match what the
        // server says, flush the stale token and force re-login.
        // This prevents cross-user data leakage on shared devices.
        if (storedUsername != null &&
            storedUsername.isNotEmpty &&
            user.username.isNotEmpty &&
            storedUsername != user.username) {
          await prefs.remove('auth_token');
          await prefs.remove('auth_username');
          state = state.copyWith(isLoading: false, token: null, user: null);
          return;
        }

        // Persist the correct username for future checks
        await prefs.setString('auth_username', user.username);
        state = state.copyWith(user: user, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      // If fetching user fails, clear all auth state
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('auth_username');
      state = state.copyWith(isLoading: false, token: null, user: null);
    }
  }

  Future<void> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _repository.login(username, password);

      final token = response['access_token'] as String? ?? '';
      if (token.isEmpty) {
        throw Exception('No access token received from server');
      }
      final userJson = response['user'] as Map<String, dynamic>? ?? {};
      final user = User.fromJson(userJson);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      // CRITICAL: Also save the username so we can detect cross-user token re-use
      await prefs.setString('auth_username', user.username);

      state = state.copyWith(
        token: token,
        user: user,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> register(String username, String password, String shopName, String industry) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.register(username, password, shopName, industry);
      // After successful registration, immediately log them in
      await login(username, password);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> logout() async {
    try {
      await _repository.logout();
    } catch (_) {
      // ignore
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('auth_username'); // CRITICAL: clear username too
      state = AuthState(); // reset to default
    }
  }
}

// The global provider for authentication state
final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
