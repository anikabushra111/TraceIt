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
    final p = phone.trim();
    if (!p.startsWith('+880')) throw 'Phone must be in +880 format';

    final trimmedEmail = email.trim();

    final res = await _auth.signUp(
      email: trimmedEmail,
      password: password,
      data: {
        'phone': p,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (department != null && department.trim().isNotEmpty)
          'department': department.trim(),
      },
    );

    final user = res.user;
    if (user == null) throw 'Signup failed (no user returned).';

    final meta = user.userMetadata ?? {};
    await _upsertProfile(
      user.id,
      email: trimmedEmail,
      name: (meta['name'] ?? name)?.toString(),
      department: (meta['department'] ?? department)?.toString(),
    );

    final metaPhone = (meta['phone'] ?? p).toString();
    if (metaPhone.trim().isNotEmpty) {
      await _upsertPhone(user.id, metaPhone);
    }
  }

  Future<void> signIn(String email, String password) async {
    final trimmedEmail = email.trim();

    final res = await _auth.signInWithPassword(
      email: trimmedEmail,
      password: password,
    );

    final user = res.user;
    if (user == null) return;

    final meta = user.userMetadata ?? {};
    await _upsertProfile(
      user.id,
      email: trimmedEmail,
      name: meta['name']?.toString(),
      department: meta['department']?.toString(),
    );

    final metaPhone = meta['phone']?.toString();
    if (metaPhone != null && metaPhone.trim().isNotEmpty) {
      await _upsertPhone(user.id, metaPhone);
    }
  }

  Future<void> _upsertProfile(
    String userId, {
    required String email,
    String? name,
    String? department,
  }) async {
    final payload = <String, dynamic>{'id': userId, 'email': email.trim()};

    final n = (name ?? '').trim();
    final d = (department ?? '').trim();
    if (n.isNotEmpty) payload['name'] = n;
    if (d.isNotEmpty) payload['department'] = d;

    await _db.from('profiles').upsert(payload, onConflict: 'id');
  }

  Future<void> _upsertPhone(String userId, String phone) async {
    final p = phone.trim();
    if (!p.startsWith('+880')) throw 'Phone must be in +880 format';

    await _db.from('profile_private').upsert({
      'user_id': userId,
      'phone': p,
    }, onConflict: 'user_id');
  }

  Future<void> resendSignupConfirmation(String email) async {
    return;
  }

  Future<void> signOut() async => _auth.signOut();

  Session? get session => _auth.currentSession;
}
