import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostPage extends StatefulWidget {
  const PostPage({super.key});

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _reward = TextEditingController();

  final _supabase = Supabase.instance.client;
  final _picker = ImagePicker();

  File? _imageFile;
  bool _loading = false;

  String? _error;
  String? _rewardError;

  String _postType = 'lost';

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 75,
    );
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  void _reset() {
    _title.clear();
    _description.clear();
    _reward.clear();
    setState(() {
      _imageFile = null;
      _error = null;
      _rewardError = null;
      _postType = 'lost';
    });
  }

  Future<void> _submit() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() => _error = 'You must be logged in to post');
      return;
    }

    final title = _title.text.trim();
    final desc = _description.text.trim();

    if (title.isEmpty || desc.isEmpty) {
      setState(() => _error = 'Title and description are required');
      return;
    }

    // Reset previous errors
    setState(() {
      _error = null;
      _rewardError = null;
    });

    final profile = await _supabase
        .from('profiles')
        .select('is_admin, points')
        .eq('id', user.id)
        .maybeSingle();

    final isAdmin = profile != null && profile['is_admin'] == true;
    final myPoints = (profile?['points'] ?? 0) as int;

    int? rewardValue;
    if (_postType == 'lost') {
      final rawReward = _reward.text.trim();

      if (rawReward.isEmpty) {
        setState(() => _rewardError = 'Reward is required');
        return;
      }

      rewardValue = int.tryParse(rawReward);
      if (rewardValue == null) {
        setState(() => _rewardError = 'Reward must be a number');
        return;
      }

      if (rewardValue < 10) {
        setState(() => _rewardError = 'Minimum reward is 10');
        return;
      }

      if (rewardValue > myPoints) {
        setState(() => _rewardError = 'Insufficient points');
        return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    String? imageUrl;
    String? imagePath;

    try {
      if (_imageFile != null) {
        imagePath =
            'posts/${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _supabase.storage
            .from('post-images')
            .upload(imagePath!, _imageFile!);
        imageUrl = _supabase.storage
            .from('post-images')
            .getPublicUrl(imagePath);
      }

      final payload = <String, dynamic>{
        'user_id': user.id,
        'post_type': _postType,
        'title': title,
        'description': desc,
        'image_url': imageUrl,
        'image_path': imagePath,
        'status': isAdmin ? 'approved' : 'pending',
        'is_resolved': false,
      };

      if (_postType == 'lost') {
        payload['reward'] = rewardValue;
      }

      await _supabase.from('posts').insert(payload);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Post created')));
      _reset();
    } on PostgrestException catch (e) {
      setState(() => _error = 'Failed to create post: ${e.message}');
    } catch (e) {
      setState(() => _error = 'Failed to create post: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _reward.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Create Post'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Post type',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _postType,
                items: const [
                  DropdownMenuItem(value: 'lost', child: Text('Lost')),
                  DropdownMenuItem(value: 'found', child: Text('Found')),
                ],
                onChanged: _loading
                    ? null
                    : (v) {
                        setState(() {
                          _postType = v ?? 'lost';
                          _rewardError = null;
                          if (_postType == 'found') _reward.clear();
                        });
                      },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Title',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _title,
                decoration: InputDecoration(
                  hintText: 'Enter the title',
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (_postType == 'lost') ...[
                Text(
                  'Reward (points)',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _reward,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: 'Minimum 10',
                    errorText: _rewardError,
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) {
                    if (_rewardError != null) {
                      setState(() => _rewardError = null);
                    }
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Description
              Text(
                'Description',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _description,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Describe the lost or found item',
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Text(
                    'Image (optional)',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _pickImage,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Add image'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_imageFile != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _imageFile!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),

              const SizedBox(height: 16),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              Row(
                children: [
                  OutlinedButton(
                    onPressed: _loading ? null : _reset,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text('Reset'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Submit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
