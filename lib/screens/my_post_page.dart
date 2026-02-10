import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trace_it/claims/claims_for_post_page.dart';

class MyPostsPage extends StatefulWidget {
  const MyPostsPage({super.key});

  @override
  State<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends State<MyPostsPage> {
  final _supabase = Supabase.instance.client;

  Future<bool> _isMeAdmin() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    final profile = await _supabase
        .from('profiles')
        .select('is_admin')
        .eq('id', user.id)
        .maybeSingle();
    return profile != null && profile['is_admin'] == true;
  }

  Future<List<Map<String, dynamic>>> _loadMyPosts() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final data = await _supabase
        .from('posts')
        .select(
          'id, title, description, status, created_at, image_url, image_path, post_type, is_resolved, reward',
        )
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return (data as List).cast<Map<String, dynamic>>();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF16A34A);
      case 'rejected':
        return const Color(0xFFDC2626);
      case 'deleted':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  Future<void> _deleteOnlyImage(Map<String, dynamic> post) async {
    final postId = post['id'] as String;
    final imagePath = (post['image_path'] ?? '').toString();
    if (imagePath.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete image?'),
        content: const Text('This will remove the image from this post.'),
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
      await _supabase.storage.from('post-images').remove([imagePath]);

      await _supabase
          .from('posts')
          .update({'image_url': null, 'image_path': null})
          .eq('id', postId);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Image deleted')));
      setState(() {});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to delete image')));
    }
  }

  Future<void> _openMyPostImageActions(Map<String, dynamic> post) async {
    final imageUrl = (post['image_url'] ?? '').toString();
    if (imageUrl.isEmpty) return;

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_full),
              title: const Text('View image'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FullImagePage(imageUrl: imageUrl),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.black),
              title: const Text(
                'Delete image',
                style: TextStyle(color: Colors.black),
              ),
              onTap: () async {
                Navigator.pop(context);
                await _deleteOnlyImage(post);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMyPost(String postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('Are you sure you want to delete this post?'),
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

  void _openEditPost(Map<String, dynamic> post) {
    final titleController = TextEditingController(text: post['title'] ?? '');
    final descController = TextEditingController(
      text: post['description'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit post'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 4,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final updates = <String, dynamic>{
                  'title': titleController.text.trim(),
                  'description': descController.text.trim(),
                };

                await _supabase
                    .from('posts')
                    .update(updates)
                    .eq('id', post['id'] as String);

                if (!mounted) return;
                Navigator.of(context).pop();
                setState(() {});
              },
              child: const Text('Save changes'),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>> _loadScreenData() async {
    final results = await Future.wait([_isMeAdmin(), _loadMyPosts()]);
    return {
      'isAdmin': results[0] as bool,
      'posts': results[1] as List<Map<String, dynamic>>,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('My posts')),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _loadScreenData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final isAdmin = snapshot.data?['isAdmin'] as bool? ?? false;
            final posts =
                snapshot.data?['posts'] as List<Map<String, dynamic>>? ?? [];

            if (posts.isEmpty) {
              return const Center(
                child: Text('You have not created any posts yet.'),
              );
            }

            final bottomPad = MediaQuery.of(context).padding.bottom;

            return ListView.builder(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPad),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final p = posts[index];
                final status = (p['status'] ?? 'pending').toString();
                final created =
                    DateTime.tryParse(p['created_at']?.toString() ?? '') ??
                    DateTime.now();

                final postType = (p['post_type'] ?? '').toString();
                final rewardRaw = p['reward'];
                final reward = rewardRaw is int
                    ? rewardRaw
                    : int.tryParse((rewardRaw ?? '').toString());

                final description = (p['description'] ?? '').toString();
                final imageUrl = (p['image_url'] ?? '').toString();
                final isResolved = p['is_resolved'] == true;

                final hasLongText = description.length > 120;
                final shortDescription = hasLongText
                    ? '${description.substring(0, 120)}...'
                    : description;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      p['title'] ?? '',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
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
                                        color: const Color(
                                          0xFF16A34A,
                                        ).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
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
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _openEditPost(p),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18),
                              onPressed: () => _deleteMyPost(p['id'] as String),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // View claims
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.inbox_outlined),
                            label: const Text('View claims'),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ClaimsForPostPage(
                                    postId: p['id'] as String,
                                    postTitle: (p['title'] ?? '').toString(),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 6),

                        if (!isAdmin)
                          Text(
                            'Status: $status',
                            style: TextStyle(
                              fontSize: 12,
                              color: _statusColor(status),
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                        // Reward (Lost only)
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

                        const SizedBox(height: 6),

                        Text(
                          shortDescription,
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (hasLongText)
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(p['title'] ?? ''),
                                  content: SingleChildScrollView(
                                    child: Text(description),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: const Text('See more'),
                          ),

                        if (imageUrl.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () => _openMyPostImageActions(p),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                imageUrl,
                                height: 170,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 10),

                        // Date
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${created.day}/${created.month}/${created.year}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class FullImagePage extends StatelessWidget {
  final String imageUrl;
  const FullImagePage({super.key, required this.imageUrl});

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
