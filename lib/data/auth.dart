import 'package:expensetracker/data/api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// true = signed in. Everything that belongs to one user (ledger, budgets, profile)
/// watches this, so it starts fresh after a login or logout.
final authProvider = AsyncNotifierProvider<AuthNotifier, bool>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    api.onSignedOut = () => state = const AsyncData(false);
    await api.load();
    return api.hasSession;
  }

  Future<void> register({
    required String name,
    required String countryCode,
    required String phone,
    required String password,
  }) async {
    final j = await api.post('/auth/register',
        auth: false,
        body: {'name': name, 'countryCode': countryCode, 'phone': phone, 'password': password});
    await _accept(j as Map<String, dynamic>);
  }

  Future<void> login({
    required String countryCode,
    required String phone,
    required String password,
  }) async {
    final j = await api.post('/auth/login',
        auth: false, body: {'countryCode': countryCode, 'phone': phone, 'password': password});
    await _accept(j as Map<String, dynamic>);
  }

  Future<void> _accept(Map<String, dynamic> j) async {
    await api.setTokens(j['accessToken'] as String, j['refreshToken'] as String);
    state = const AsyncData(true);
  }

  Future<void> logout() async {
    final r = api.refreshToken;
    try {
      if (r != null) await api.post('/auth/logout', auth: false, body: {'refreshToken': r});
    } catch (_) {} // offline: the token still expires on its own
    await api.clear();
    state = const AsyncData(false);
  }
}
