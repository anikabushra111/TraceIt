import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _auth = Supabase.instance.client.auth;
  final _db = Supabase.instance.client;

  Future<void> signUp(
    String email,
    String password, {
    required String phone,
    String? name,
    String? department,
  }) async {
    final res = await _auth.signUp(email: email, password: password);

    if (res.session == null) {
      await _auth.signInWithPassword(email: email, password: password);
    }

    final user = _auth.currentUser;
    if (user == null) throw 'Signup/login failed (no currentUser)';

    await _ensureProfile(user.id, name: name, department: department);
    await _upsertPhone(user.id, phone);
  }

  Future<void> signIn(String email, String password) async {
    final res = await _auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = res.user;
    if (user != null) {
      await _ensureProfile(user.id);
    }
  }

  Future<void> _ensureProfile(
    String userId, {
    String? name,
    String? department,
  }) async {
    final existing = await _db
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (existing != null) return;

    await _db.from('profiles').insert({
      'id': userId,
      if (name != null && name.isNotEmpty) 'name': name,
      if (department != null && department.isNotEmpty) 'department': department,
    });
  }

  Future<void> _upsertPhone(String userId, String phone) async {
    final p = phone.trim();
    if (!p.startsWith('+880')) {
      throw 'Phone must be in +880 format';
    }
    await _db.from('profile_private').upsert({
      'user_id': userId,
      'phone': p,
    }, onConflict: 'user_id');
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Session? get session => _auth.currentSession;
}
