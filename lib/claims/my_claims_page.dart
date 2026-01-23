import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyClaimsPage extends StatefulWidget {
  const MyClaimsPage({super.key});

  @override
  State<MyClaimsPage> createState() => _MyClaimsPageState();
}

class _MyClaimsPageState extends State<MyClaimsPage> {
  final _supabase = Supabase.instance.client;
  late final Stream<List<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();

    final user = _supabase.auth.currentUser;
    if (user == null) {
      _stream = const Stream.empty();
      return;
    }

    _stream = _supabase
        .from('claims')
        .stream(primaryKey: ['id'])
        .eq('claimer_id', user.id)
        .order('created_at', ascending: false);
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
      case 'pending':
        return 'Pending';
      default:
        return 'Pending';
    }
  }

  // ✅ NEW: map owner-side closed reasons into claimer-friendly text
  String _closedReasonForClaimer(String raw) {
    final r = raw.trim();
    if (r.isEmpty) return 'This claim was closed.';

    final lower = r.toLowerCase();
    if (lower.contains('already accepted one claim')) {
      return 'This claim was closed because the owner accepted another claim for this post.';
    }

    return r;
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('My claims')),
      body: user == null
          ? const Center(child: Text('Please log in.'))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _stream,
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

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: claims.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final c = claims[i];

                    final status = (c['status'] ?? 'pending').toString();
                    final label = _statusLabel(status);

                    final message = (c['message'] ?? '').toString();
                    final createdAt = (c['created_at'] ?? '').toString();

                    final ownerReply = (c['owner_reply'] ?? '').toString();
                    final ownerPhone = (c['owner_contact_phone'] ?? '')
                        .toString();

                    final closedReasonRaw = (c['closed_reason'] ?? '')
                        .toString();
                    final closedReason = _closedReasonForClaimer(
                      closedReasonRaw,
                    );

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
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: _statusColor(status),
                                    ),
                                  ),
                                ),
                                Text(
                                  createdAt,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(message),

                            if (status == 'accepted' &&
                                (ownerReply.isNotEmpty ||
                                    ownerPhone.isNotEmpty)) ...[
                              const SizedBox(height: 10),
                              if (ownerReply.isNotEmpty)
                                Text(
                                  'Owner message: $ownerReply',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              if (ownerPhone.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Owner phone: $ownerPhone',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ],

                            if (status == 'closed') ...[
                              const SizedBox(height: 10),
                              Text(
                                closedReason,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
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
