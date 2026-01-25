import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _auth = Supabase.instance.client.auth;
  final _db = Supabase.instance.client;

  static const _emailRedirectTo = 'traceit://login-callback';

  Future<void> signUp(
    String email,
    String password, {
    required String phone,
    String? name,
    String? department,
  }) async {
    final p = phone.trim();
    if (!p.startsWith('+880')) {
      throw 'Phone must be in +880 format';
    }

    final res = await _auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: _emailRedirectTo,
      data: {
        'phone': p,
        if (name != null && name.isNotEmpty) 'name': name,
        if (department != null && department.isNotEmpty)
          'department': department,
      },
    );

    // With email confirmation ON, session is usually null until user verifies. [web:409]
    if (res.user == null) {
      throw 'Signup failed (no user returned)';
    }

    // Do NOT sign in here.
    // After the user confirms email, they will sign in, and we will create profile + phone then.
  }

  Future<void> signIn(String email, String password) async {
    final res = await _auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = res.user;
    if (user == null) return;

    final meta = user.userMetadata ?? {};
    final metaName = meta['name']?.toString();
    final metaDept = meta['department']?.toString();
    final metaPhone = meta['phone']?.toString();

    await _ensureProfile(user.id, name: metaName, department: metaDept);

    if (metaPhone != null && metaPhone.isNotEmpty) {
      await _upsertPhone(user.id, metaPhone);
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
