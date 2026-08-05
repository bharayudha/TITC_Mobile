import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:magang_titc/models/activity_model.dart';
import 'package:magang_titc/services/auth_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class PostDetailScreen extends StatelessWidget {
  final ActivityModel post;

  const PostDetailScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2124),
      appBar: AppBar(
        title: const Text('Post Detail', style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: const Color(0xFF2B2E33),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2B2E33),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: post.avatarUrl.isNotEmpty ? CachedNetworkImageProvider(post.avatarUrl, headers: AuthService.imageAuthHeaders) : null,
                    backgroundColor: Colors.grey,
                    child: post.avatarUrl.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post.authorName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        Text(
                          post.date,
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                post.content.replaceAll(RegExp(r'<[^>]*>'), '').trim(),
                style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
              ),
              if (post.mediaUrl != null && post.mediaUrl!.isNotEmpty) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(imageUrl: post.mediaUrl!, httpHeaders: AuthService.imageAuthHeaders, fit: BoxFit.cover, width: double.infinity),
                ),
              ],
              const SizedBox(height: 16),
              Divider(color: Colors.grey.shade700),
              Row(
                children: [
                  Icon(PhosphorIconsRegular.heart, color: Colors.grey.shade400, size: 18),
                  const SizedBox(width: 8),
                  Text('${post.likeCount} likes', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                  const SizedBox(width: 24),
                  Icon(PhosphorIconsRegular.chatCircle, color: Colors.grey.shade400, size: 18),
                  const SizedBox(width: 8),
                  Text('${post.commentCount} comments', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
