import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';
import 'package:mobile/features/auth/domain/models/user_model.dart';

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

// StateNotifier for AuthState
class AuthNotifier extends Notifier<AuthState> {
  late final AuthRepository _repository;

  @override
  AuthState build() {
    _repository = ref.watch(authRepositoryProvider);
    
    // Register global 401 handler
    ApiClient.onUnauthorized = () {
      if (state.isAuthenticated) {
        logout();
      }
    };
    
    Future.microtask(() => _checkInitialAuth());
    return AuthState(isLoading: true);
  }

  Future<void> _checkInitialAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token != null) {
        state = state.copyWith(token: token);
        final user = await _repository.getMe();
        state = state.copyWith(user: user, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      // If fetching user fails, clear token
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
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

  Future<void> logout() async {
    try {
      await _repository.logout();
    } catch (_) {
      // ignore
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      state = AuthState(); // reset to default
    }
  }
}

// The global provider for authentication state
final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
