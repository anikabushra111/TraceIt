import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trace_it/claims/claims_service.dart';
import 'package:postgrest/postgrest.dart';
import 'package:intl/intl.dart';

import '../widgets/bd_phone_field.dart';

class ClaimsForPostPage extends StatefulWidget {
  const ClaimsForPostPage({
    super.key,
    required this.postId,
    required this.postTitle,
  });

  final String postId;
  final String postTitle;

  @override
  State<ClaimsForPostPage> createState() => _ClaimsForPostPageState();
}

class _ClaimsForPostPageState extends State<ClaimsForPostPage> {
  final _service = ClaimsService();
  final _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> _load() {
    return _service.listClaimsForMyPosts(postId: widget.postId);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'closed':
        return Colors.grey;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Rejected';
      case 'closed':
        return 'Closed';
      default:
        return '';
    }
  }

  String _formatDateOnly(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    return DateFormat('dd/MM/yyyy').format(dt.toLocal());
  }

  Future<Map<String, String>> _loadClaimerBasic(String claimerId) async {
    final row = await _supabase
        .from('profiles')
        .select('name, department')
        .eq('id', claimerId)
        .maybeSingle();

    final name = (row?['name'] ?? 'Unknown user').toString();
    final dept = (row?['department'] ?? 'Not set').toString();
    return {'name': name, 'department': dept};
  }

  // NEW: load full details for dialog (Name, Dept, Email, Points, Admin flag if you need)
  Future<Map<String, dynamic>?> _loadFullProfile(String uid) async {
    final row = await _supabase
        .from('profiles')
        .select('name, department, email, points, is_admin')
        .eq('id', uid)
        .maybeSingle();
    return row;
  }

  // NEW: show dialog like HomePage (basic info + email)
  Future<void> _showUserDetailsDialog(String uid) async {
    final row = await _loadFullProfile(uid);

    if (!mounted) return;

    final p = row ?? {};
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('User details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Name: ${p['name'] ?? 'Unknown'}'),
              Text('Department: ${p['department'] ?? 'Not set'}'),
              const SizedBox(height: 8),
              Text('Email: ${p['email'] ?? 'Not stored'}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _acceptFlow(Map<String, dynamic> claimRow) async {
    final phoneCtrl = TextEditingController();
    final msgCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept claim'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BdPhoneField(controller: phoneCtrl),
            const SizedBox(height: 10),
            TextField(
              controller: msgCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message to claimer',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final local = phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    final msg = msgCtrl.text.trim();

    if (!BdPhoneField.isValidBdMobileLocalPart(local)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid phone. Use 1XXXXXXXXX (after +880).'),
        ),
      );
      return;
    }
    if (msg.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message is required')));
      return;
    }

    final phoneE164 = BdPhoneField.toE164(local);

    try {
      await _service.ownerAcceptClaim(
        claimId: claimRow['id'].toString(),
        ownerContactPhone: phoneE164,
        ownerReply: msg,
      );
      if (!mounted) return;
      setState(() {});
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _rejectFlow(Map<String, dynamic> claimRow) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject claim?'),
        content: const Text('Are you sure you want to reject it?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _service.ownerRejectClaim(claimId: claimRow['id'].toString());
      if (!mounted) return;
      setState(() {});
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Claims: ${widget.postTitle}')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load claims'));
          }

          final claims = snapshot.data ?? [];
          if (claims.isEmpty) {
            return const Center(child: Text('No claims yet.'));
          }

          final hasAccepted = claims.any(
            (c) => (c['status'] ?? 'pending').toString() == 'accepted',
          );

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: claims.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final c = claims[i];

              final status = (c['status'] ?? 'pending').toString();
              final statusLabel = _statusLabel(status);

              final claimerId = (c['claimer_id'] ?? '').toString();
              final message = (c['message'] ?? '').toString();
              final imageUrl = (c['image_url'] ?? '').toString();

              final createdAtRaw = (c['created_at'] ?? '').toString();
              final createdAtText = _formatDateOnly(createdAtRaw);

              final ownerReply = (c['owner_reply'] ?? '').toString();
              final ownerPhone = (c['owner_contact_phone'] ?? '').toString();
              final closedReason = (c['closed_reason'] ?? '').toString();

              final isAccepted = status == 'accepted';
              final isClosed = status == 'closed';

              final canAct = status == 'pending' && !hasAccepted;

              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: statusLabel.isEmpty
                                ? const SizedBox.shrink()
                                : Text(
                                    statusLabel,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: _statusColor(status),
                                    ),
                                  ),
                          ),
                          Text(
                            createdAtText,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // CHANGED: make this tappable to open the user details dialog
                      FutureBuilder<Map<String, String>>(
                        future: _loadClaimerBasic(claimerId),
                        builder: (context, snap) {
                          final name = snap.data?['name'] ?? 'Loading...';
                          final dept = snap.data?['department'] ?? '';

                          return InkWell(
                            onTap: claimerId.isEmpty
                                ? null
                                : () => _showUserDetailsDialog(claimerId),
                            child: Row(
                              children: [
                                const CircleAvatar(
                                  radius: 14,
                                  child: Icon(Icons.person, size: 16),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (dept.isNotEmpty)
                                      Text(
                                        dept,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 10),
                      Text(message, style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 10),

                      // UI FIX: smaller, proportional proof image preview
                      if (imageUrl.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    _FullImagePage(imageUrl: imageUrl),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Image.network(imageUrl, fit: BoxFit.cover),
                            ),
                          ),
                        ),

                      if (isAccepted && ownerReply.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Your reply: $ownerReply',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                      if (isAccepted && ownerPhone.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Phone shared: $ownerPhone',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                      if (!isAccepted) ...[
                        const SizedBox(height: 10),
                        Text(
                          isClosed && closedReason.isNotEmpty
                              ? closedReason
                              : (hasAccepted
                                    ? "You've already accepted one claim"
                                    : ''),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: canAct ? () => _acceptFlow(c) : null,
                              child: const Text('Accept'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: canAct ? () => _rejectFlow(c) : null,
                              child: const Text('Reject'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _FullImagePage extends StatelessWidget {
  final String imageUrl;
  const _FullImagePage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(child: InteractiveViewer(child: Image.network(imageUrl))),
    );
  }
}
