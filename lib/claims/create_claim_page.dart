import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'claims_service.dart';

class CreateClaimPage extends StatefulWidget {
  const CreateClaimPage({
    super.key,
    required this.postId,
    required this.postOwnerId,
    required this.postType,
  });

  final String postId;
  final String postOwnerId;
  final String postType;

  @override
  State<CreateClaimPage> createState() => _CreateClaimPageState();
}

class _CreateClaimPageState extends State<CreateClaimPage> {
  final _message = TextEditingController();
  final _picker = ImagePicker();

  File? _imageFile;
  bool _loading = false;
  String? _error;

  bool get _isLost => widget.postType.toLowerCase() == 'lost';

  String get _imageButtonText {
    if (_isLost) {
      return 'Add image (You must add the photo of the item that you\'ve found)';
    }
    return 'Add image (optional)';
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 75,
    );
    if (picked == null) return;
    setState(() => _imageFile = File(picked.path));
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    // NEW: require photo for lost posts
    if (_isLost && _imageFile == null) {
      setState(() {
        _loading = false;
        _error = 'For lost posts, you must add a photo of the item you found.';
      });
      return;
    }

    try {
      await ClaimsService().createClaim(
        postId: widget.postId,
        postOwnerId: widget.postOwnerId,
        message: _message.text,
        imageFile: _imageFile,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Claim it')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isLost
                    ? "Write a message to the owner to prove you've really found this item."
                    : "Write a message to the owner to prove this item belongs to you.",
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _message,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _pickImage,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(_imageButtonText),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_imageFile != null) const Text('Selected'),
                ],
              ),
              const SizedBox(height: 12),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit claim'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
