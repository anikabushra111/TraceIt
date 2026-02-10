import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/notification_bell.dart';
import 'post_page.dart';
import 'profile_page.dart';
import 'package:trace_it/claims/create_claim_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _supabase = Supabase.instance.client;

  int _tabIndex = 0;
  int _profileReload = 0;

  String _searchText = '';
  String _sort = 'newest';

  final _searchController = TextEditingController();

  bool _isCurrentUserAdmin = false;
  String? _currentUserId;

  bool _exitArmed = false;
  Timer? _exitTimer;

  @override
  void dispose() {
    _exitTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: _tabIndex == 0 && _exitArmed,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (_tabIndex != 0) {
          setState(() {
            _tabIndex = 0;
            _exitArmed = false;
          });
          return;
        }

        if (!_exitArmed) {
          setState(() => _exitArmed = true);

          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Press back again to exit')),
          );

          _exitTimer?.cancel();
          _exitTimer = Timer(const Duration(seconds: 2), () {
            if (!mounted) return;
            setState(() => _exitArmed = false);
          });
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _tabIndex == 0
            ? AppBar(
                actions: [
                  const NotificationBell(),
                  IconButton(
                    icon: const Icon(Icons.logout),
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
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Log out'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await _supabase.auth.signOut();
                        if (!mounted) return;
                      }
                    },
                  ),
                ],
              )
            : null,
        body: SafeArea(
          child: IndexedStack(
            index: _tabIndex,
            children: [
              _buildFeedBody(context, theme),
              const PostPage(),
              ProfilePage(key: ValueKey(_profileReload)),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _tabIndex,
          onTap: (i) => setState(() {
            _tabIndex = i;
            _exitArmed = false;

            if (i == 2) _profileReload++;
          }),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_box_outlined),
              label: 'Post',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedBody(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Trace It',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: const Color(0xFF1F3A93),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
          child: Text(
            "Because lost shouldn’t mean gone.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF6B7280),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search posts...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) =>
                      setState(() => _searchText = value.trim()),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort),
                onSelected: (value) => setState(() => _sort = value),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'newest', child: Text('Newest')),
                  PopupMenuItem(value: 'oldest', child: Text('Oldest')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchPosts(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Center(child: Text('Failed to load posts'));
              }

              final posts = snapshot.data ?? [];
              if (posts.isEmpty) {
                return const _EmptyHome();
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  return _PostCard(
                    post: post,
                    isAdmin: _isCurrentUserAdmin,
                    currentUserId: _currentUserId,
                    onUpdateStatus: _updatePostStatus,
                    onDelete: _deletePost,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _fetchPosts() async {
    final user = _supabase.auth.currentUser;

    bool isAdmin = false;
    if (user != null) {
      _currentUserId = user.id;

      final profile = await _supabase
          .from('profiles')
          .select('is_admin')
          .eq('id', user.id)
          .maybeSingle();
      if (profile != null && profile['is_admin'] == true) {
        isAdmin = true;
      }
    }
    _isCurrentUserAdmin = isAdmin;

    final baseQuery = _supabase
        .from('posts')
        .select(
          'id, user_id, title, description, image_url, image_path, created_at, status, post_type, is_resolved, reward',
        );

    final filteredQuery = isAdmin
        ? baseQuery
        : baseQuery.eq('status', 'approved');

    final data = await filteredQuery
        .order('is_resolved', ascending: true)
        .order('created_at', ascending: _sort == 'oldest');

    List<Map<String, dynamic>> posts = (data as List)
        .cast<Map<String, dynamic>>();

    if (_searchText.isNotEmpty) {
      final q = _searchText.toLowerCase();
      posts = posts.where((p) {
        final title = (p['title'] ?? '').toString().toLowerCase();
        final desc = (p['description'] ?? '').toString().toLowerCase();
        return title.contains(q) || desc.contains(q);
      }).toList();
    }

    return posts;
  }

  Future<void> _updatePostStatus(String postId, String newStatus) async {
    await _supabase
        .from('posts')
        .update({'status': newStatus})
        .eq('id', postId);
    setState(() {});
  }

  Future<void> _deletePost(String postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text(
          'Are you sure you want to delete this post? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final row = await _supabase
          .from('posts')
          .select('image_path')
          .eq('id', postId)
          .maybeSingle();
      final imagePath = (row?['image_path'] ?? '').toString();
      if (imagePath.isNotEmpty) {
        await _supabase.storage.from('post-images').remove([imagePath]);
      }

      await _supabase.from('posts').delete().eq('id', postId);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Post deleted')));
      setState(() {});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to delete post')));
    }
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No Posts Yet!',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start posting about lost or found items',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostAuthor extends StatelessWidget {
  final String? userId;
  const _PostAuthor({this.userId});

  Future<Map<String, dynamic>?> _loadFullProfile(String uid) async {
    final supabase = Supabase.instance.client;
    final data = await supabase
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();
    return data;
  }

  Future<String?> _loadPhoneIfAdmin(String uid) async {
    final supabase = Supabase.instance.client;
    try {
      final row = await supabase
          .from('profile_private')
          .select('phone')
          .eq('user_id', uid)
          .maybeSingle();
      return row?['phone']?.toString();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = userId;
    if (uid == null) return const SizedBox.shrink();

    final supabase = Supabase.instance.client;

    return FutureBuilder<Map<String, dynamic>?>(
      future: supabase
          .from('profiles')
          .select('name, department, is_admin')
          .eq('id', uid)
          .maybeSingle(),
      builder: (context, snapshot) {
        final name = (snapshot.data?['name'] as String?) ?? 'Unknown user';
        final department =
            (snapshot.data?['department'] as String?) ?? 'Not set';
        final isAuthorAdmin = snapshot.data?['is_admin'] == true;

        return InkWell(
          onTap: () async {
            final viewer = supabase.auth.currentUser;
            if (viewer == null) return;

            final viewerProfile = await supabase
                .from('profiles')
                .select('is_admin')
                .eq('id', viewer.id)
                .maybeSingle();
            final viewerIsAdmin =
                viewerProfile != null && viewerProfile['is_admin'] == true;

            final fullProfile = await _loadFullProfile(uid);

            String? phone;
            if (viewerIsAdmin) {
              phone = await _loadPhoneIfAdmin(uid);
            }

            if (!context.mounted) return;
            final p = fullProfile ?? {};

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
                      if (viewerIsAdmin) ...[
                        Text('Phone: ${phone ?? 'Not stored'}'),
                        Text('Points: ${p['points']?.toString() ?? '0'}'),
                        Text('Admin: ${p['is_admin'] == true ? 'Yes' : 'No'}'),
                      ],
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
          },
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
                  Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      if (isAuthorAdmin) ...[
                        const SizedBox(width: 6),
                        const Text(
                          '(Admin)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    department,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool isAdmin;
  final String? currentUserId;
  final Future<void> Function(String postId, String newStatus) onUpdateStatus;
  final Future<void> Function(String postId) onDelete;

  const _PostCard({
    required this.post,
    required this.isAdmin,
    required this.currentUserId,
    required this.onUpdateStatus,
    required this.onDelete,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _expanded = false;

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String okText,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(okText),
          ),
        ],
      ),
    );
    return res == true;
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;

    final String postId = post['id'] as String;
    final String? userId = post['user_id'] as String?;
    final DateTime created =
        DateTime.tryParse(post['created_at']?.toString() ?? '') ??
        DateTime.now();

    final bool isResolved = post['is_resolved'] == true;

    final String? imageUrl = post['image_url'] as String?;
    final String description = (post['description'] as String?) ?? '';
    final String status = (post['status'] ?? 'pending') as String;

    final String postType = (post['post_type'] ?? 'found').toString();
    final rewardRaw = post['reward'];
    final int? reward = rewardRaw is int
        ? rewardRaw
        : int.tryParse((rewardRaw ?? '').toString());

    final bool hasLongText = description.length > 120;
    final shortDescription = hasLongText
        ? '${description.substring(0, 120)}...'
        : description;

    Color statusColor;
    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

    final primary = Theme.of(context).colorScheme.primary;
    final bool isOwnPost =
        widget.currentUserId != null && userId == widget.currentUserId;

    final textColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PostAuthor(userId: userId),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      post['title'] ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isResolved) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Resolved',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${created.day}/${created.month}/${created.year}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (widget.isAdmin && !isOwnPost)
          Text(
            'Status: $status',
            style: TextStyle(fontSize: 12, color: statusColor),
          ),
        if (postType == 'lost' && reward != null) ...[
          const SizedBox(height: 6),
          Text(
            'Reward: $reward points',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          _expanded || !hasLongText ? description : shortDescription,
          style: const TextStyle(fontSize: 14),
        ),
        if (hasLongText)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? 'See less' : 'See more'),
            ),
          ),
        if (userId != null)
          _ClaimButton(
            postId: postId,
            postOwnerId: userId,
            postType: (post['post_type'] ?? 'found').toString(),
            isOwnPost: isOwnPost,
            isAdmin: widget.isAdmin,
            isResolved: isResolved,
            postStatus: status,
          ),
        if (widget.isAdmin) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!isOwnPost && status == 'pending')
                ElevatedButton(
                  onPressed: () async {
                    final ok = await _confirmAction(
                      title: 'Approve post?',
                      message: 'Are you sure you want to approve this post?',
                      okText: 'Approve',
                    );
                    if (ok) widget.onUpdateStatus(postId, 'approved');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  child: const Text('Approve'),
                ),
              if (!isOwnPost && status == 'pending')
                OutlinedButton(
                  onPressed: () async {
                    final ok = await _confirmAction(
                      title: 'Reject post?',
                      message: 'Are you sure you want to reject this post?',
                      okText: 'Reject',
                    );
                    if (ok) widget.onUpdateStatus(postId, 'rejected');
                  },
                  style: OutlinedButton.styleFrom(foregroundColor: primary),
                  child: const Text('Reject'),
                ),
              IconButton(
                icon: Icon(Icons.delete, color: primary),
                onPressed: () => widget.onDelete(postId),
              ),
            ],
          ),
        ],
      ],
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: textColumn),
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _FullImagePage(imageUrl: imageUrl),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ClaimButton extends StatefulWidget {
  const _ClaimButton({
    required this.postId,
    required this.postOwnerId,
    required this.postType,
    required this.isOwnPost,
    required this.isAdmin,
    required this.isResolved,
    required this.postStatus,
  });

  final String postId;
  final String postOwnerId;
  final String postType;
  final bool isOwnPost;
  final bool isAdmin;
  final bool isResolved;
  final String postStatus;

  @override
  State<_ClaimButton> createState() => _ClaimButtonState();
}

class _ClaimButtonState extends State<_ClaimButton> {
  final _supabase = Supabase.instance.client;

  Future<bool> _alreadyClaimed() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return true;

    final row = await _supabase
        .from('claims')
        .select('id')
        .eq('post_id', widget.postId)
        .eq('claimer_id', user.id)
        .maybeSingle();

    return row != null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isOwnPost) return const SizedBox.shrink();
    if (widget.postStatus != 'approved') return const SizedBox.shrink();
    if (widget.isResolved) return const SizedBox.shrink();

    return FutureBuilder<bool>(
      future: _alreadyClaimed(),
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final claimed = snapshot.data == true;

        final disabled = loading || claimed;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: disabled
                  ? null
                  : () async {
                      final ok = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => CreateClaimPage(
                            postId: widget.postId,
                            postOwnerId: widget.postOwnerId,
                            postType: widget.postType,
                          ),
                        ),
                      );

                      if (!mounted) return;
                      setState(() {});

                      if (ok == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Claim submitted')),
                        );
                      }
                    },
              child: loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(claimed ? 'Already claimed' : 'Claim it'),
            ),
          ],
        );
      },
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
