import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trace_it/auth/auth_service.dart';
import 'package:trace_it/auth/auth_gate.dart';
import 'package:trace_it/screens/my_post_page.dart';
import 'package:trace_it/claims/my_claims_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _supabase = Supabase.instance.client;
  final _authService = AuthService();

  Future<Map<String, dynamic>?> _loadProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final data = await _supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) return {'email': user.email};
    return {
      'name': data['name'],
      'department': data['department'],
      'points': data['points'],
      'email': user.email,
    };
  }

  Future<void> _editName(String currentName) async {
    final controller = TextEditingController(text: currentName);
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit name'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newName == null || newName.isEmpty) return;

    await _supabase
        .from('profiles')
        .update({'name': newName})
        .eq('id', user.id);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _loadProfile(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final profile = snapshot.data;
            final name = profile?['name']?.toString() ?? 'Unknown';
            final department = profile?['department']?.toString() ?? 'Not set';
            final email = profile?['email']?.toString() ?? 'No email';
            final points = profile?['points']?.toString() ?? '0';

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'TraceIt',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 24),

                Center(
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: const Color(0xFFE5E7EB),
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                _ProfileField(
                  label: 'Name',
                  value: name,
                  showEdit: true,
                  onTap: () => _editName(name),
                ),
                const SizedBox(height: 16),

                _ProfileField(label: 'Department', value: department),
                const SizedBox(height: 16),

                _ProfileField(label: 'Email', value: email),
                const SizedBox(height: 16),

                _ProfileField(
                  label: 'Points',
                  value: points,
                  trailing: const Icon(
                    Icons.star,
                    color: Color(0xFFF59E0B),
                    size: 20,
                  ),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MyPostsPage()),
                      );
                    },
                    child: const Text('My posts'),
                  ),
                ),
                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MyClaimsPage()),
                      );
                    },
                    child: const Text('My claims'),
                  ),
                ),
                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Log out?'),
                          content: const Text(
                            'Are you sure you want to log out of TraceIt?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Log out'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await _authService.signOut();

                        if (!mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const AuthGate()),
                          (route) => false,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFF1F3A93),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text('Logout'),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final String label;
  final String value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showEdit;

  const _ProfileField({
    required this.label,
    required this.value,
    this.trailing,
    this.onTap,
    this.showEdit = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
              if (trailing != null) trailing!,
              if (showEdit)
                TextButton(onPressed: onTap, child: const Text('Edit')),
            ],
          ),
        ),
      ],
    );
  }
}
