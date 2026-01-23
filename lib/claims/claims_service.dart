import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClaimsService {
  ClaimsService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>> createClaim({
    required String postId,
    required String postOwnerId,
    required String message,
    String claimKind = 'owner_claim',
    File? imageFile,
    String bucket = 'post-images',
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to create a claim.');
    }

    final msg = message.trim();
    if (msg.isEmpty) throw Exception('Message is required.');

    String? imagePath;
    String? imageUrl;

    try {
      if (imageFile != null) {
        imagePath =
            'claims/${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _client.storage.from(bucket).upload(imagePath, imageFile);
        imageUrl = _client.storage.from(bucket).getPublicUrl(imagePath);
      }

      final row = await _client
          .from('claims')
          .insert({
            'post_id': postId,
            'post_owner_id': postOwnerId,
            'claimer_id': user.id,
            'claim_kind': claimKind,
            'message': msg,
            'image_url': imageUrl,
            'image_path': imagePath,
            'status': 'pending',
          })
          .select()
          .single();

      return row;
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw Exception(
          'You already submitted a claim for this post. You cannot claim again.',
        );
      }
      throw Exception(e.message);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> ownerRejectClaim({required String claimId}) async {
    await _client
        .from('claims')
        .update({'status': 'rejected'})
        .eq('id', claimId);
  }

  Future<void> ownerAcceptClaim({
    required String claimId,
    required String ownerContactPhone,
    required String ownerReply,
  }) async {
    await _client.rpc(
      'accept_claim_and_resolve',
      params: {
        'p_claim_id': claimId,
        'p_owner_contact_phone': ownerContactPhone,
        'p_owner_reply': ownerReply,
      },
    );
  }

  Future<List<Map<String, dynamic>>> listMyClaims() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('You must be logged in.');

    final data = await _client
        .from('claims')
        .select(
          'id, created_at, post_id, post_owner_id, claimer_id, claim_kind, message, image_url, image_path, status, owner_reply, owner_contact_phone, closed_reason, closed_at',
        )
        .eq('claimer_id', user.id)
        .order('created_at', ascending: false);

    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> listClaimsForMyPosts({
    String? postId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('You must be logged in.');

    var query = _client
        .from('claims')
        .select(
          'id, created_at, post_id, post_owner_id, claimer_id, claim_kind, message, image_url, image_path, status, owner_reply, owner_contact_phone, closed_reason, closed_at',
        )
        .eq('post_owner_id', user.id);

    if (postId != null) query = query.eq('post_id', postId);

    final data = await query.order('created_at', ascending: false);
    return (data as List).cast<Map<String, dynamic>>();
  }
}
