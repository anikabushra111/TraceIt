import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class MyClaimsPage extends StatefulWidget {
  const MyClaimsPage({super.key});

  @override
  State<MyClaimsPage> createState() => _MyClaimsPageState();
}

class _MyClaimsPageState extends State<MyClaimsPage> {
  final _supabase = Supabase.instance.client;

  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadClaimsWithPost();
  }

  Future<List<Map<String, dynamic>>> _loadClaimsWithPost() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final data = await _supabase
        .from('claims')
        .select(
          'id, created_at, post_id, message, status, owner_reply, owner_contact_phone, closed_reason, closed_at, image_url, '
          'post:posts(id, title, post_type, reward, status, is_resolved, image_url)',
        )
        .eq('claimer_id', user.id)
        .order('created_at', ascending: false);

    return (data as List).cast<Map<String, dynamic>>();
  }

  void _reload() {
    setState(() {
      _future = _loadClaimsWithPost();
    });
  }

  String _formatDateOnly(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    return DateFormat('dd/MM/yyyy').format(dt.toLocal());
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

  String _closedReasonForClaimer(String raw) {
    final r = raw.trim();
    if (r.isEmpty) return 'This claim was closed.';

    final lower = r.toLowerCase();
    if (lower.contains('already accepted one claim')) {
      return 'This claim was closed because the owner accepted another claim for this post.';
    }

    return r;
  }

  int? _asInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse((v ?? '').toString());
  }

  // Compact image that never covers the screen
  Widget _netImage(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: const Color(0xFFF3F4F6),
              alignment: Alignment.center,
              child: const Text(
                'Image not available',
                style: TextStyle(color: Colors.grey),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My claims'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _reload),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Please log in.'))
          : FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
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
                  // IMPORTANT: bottom safe-area padding so last card is visible
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPad),
                  itemCount: claims.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final c = claims[i];

                    final status = (c['status'] ?? 'pending').toString();
                    final label = _statusLabel(status);

                    final message = (c['message'] ?? '').toString();

                    final createdAtRaw = (c['created_at'] ?? '').toString();
                    final createdAtText = _formatDateOnly(createdAtRaw);

                    final ownerReply = (c['owner_reply'] ?? '').toString();
                    final ownerPhone = (c['owner_contact_phone'] ?? '')
                        .toString();

                    final closedReasonRaw = (c['closed_reason'] ?? '')
                        .toString();
                    final closedReason = _closedReasonForClaimer(
                      closedReasonRaw,
                    );

                    final post = c['post'] as Map<String, dynamic>?;
                    final postTitle = (post?['title'] ?? 'Post not available')
                        .toString();
                    final postType = (post?['post_type'] ?? '').toString();
                    final reward = _asInt(post?['reward']);
                    final postImageUrl = (post?['image_url'] ?? '').toString();

                    final claimImageUrl = (c['image_url'] ?? '').toString();

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
                                  createdAtText,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            Text(
                              'Post: $postTitle',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (postType.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Type: $postType',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                            if (postType == 'lost' && reward != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Reward: $reward points',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],

                            if (postImageUrl.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _netImage(postImageUrl),
                            ],

                            const SizedBox(height: 10),
                            Text(message),

                            if (claimImageUrl.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _netImage(claimImageUrl),
                            ],

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
