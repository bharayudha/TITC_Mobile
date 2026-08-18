import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:magang_titc/constants/app_colors.dart';
import 'package:magang_titc/models/activity_model.dart';
import 'package:magang_titc/screens/customer/spaces/space_webview_screen.dart';
import 'package:magang_titc/services/api_service.dart';
import 'package:magang_titc/services/auth_service.dart';
import 'package:magang_titc/widgets/shared/search_overlay.dart';

/// Hasil pencarian post dari ikon 🔍 di app bar.
///
/// Mengikuti perilaku portal web: yang dicari adalah POST lewat endpoint
/// `/feeds` dengan parameter `search`, dipersempit per Space lewat `space`.
class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({super.key, required this.request});

  final SearchRequest request;

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late Future<List<ActivityModel>> _resultsFuture;

  @override
  void initState() {
    super.initState();
    _resultsFuture = ApiService.searchFeeds(
      query: widget.request.query,
      spaceSlug: widget.request.spaceSlug,
      includeComments: widget.request.includeComments,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 3,
        scrolledUnderElevation: 3,
        shadowColor: kShadowColor,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '"${widget.request.query}"',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.request.spaceLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
      body: FutureBuilder<List<ActivityModel>>(
        future: _resultsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _buildMessage(
              'Gagal memuat hasil. Periksa koneksi lalu coba lagi.',
            );
          }
          final results = snapshot.data ?? const [];
          if (results.isEmpty) {
            return _buildMessage(
              'Tidak ada post yang cocok dengan "${widget.request.query}"'
              '${widget.request.spaceSlug.isEmpty ? '' : ' di ${widget.request.spaceLabel}'}.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: results.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _buildPostCard(results[index]),
          );
        },
      ),
    );
  }

  Widget _buildMessage(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.black54),
      ),
    ),
  );

  Widget _buildPostCard(ActivityModel post) {
    // Konten feed berisi HTML; tag-nya dibuang supaya preview tetap terbaca
    // sebagai teks biasa, sama seperti yang dilakukan model chat.
    final plain = post.content.replaceAll(RegExp(r'<[^>]*>'), ' ').trim();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: post.permalink == null || post.permalink!.isEmpty
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SpaceWebViewScreen(
                    overrideUrl: post.permalink!,
                    title: post.spaceName ?? 'Post',
                  ),
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildAvatar(post),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      post.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  if (post.spaceName != null && post.spaceName!.isNotEmpty)
                    Flexible(
                      child: Text(
                        post.spaceName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                ],
              ),
              if (plain.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  plain,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(ActivityModel post) {
    const size = 28.0;
    final initial = post.authorName.isEmpty
        ? '?'
        : post.authorName[0].toUpperCase();

    Widget fallback() => CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.grey.shade300,
      child: Text(
        initial,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
      ),
    );

    if (post.avatarUrl.isEmpty) return fallback();

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: post.avatarUrl,
        // Sebagian media ada di balik privacy WordPress, sama seperti call
        // site gambar lain di app.
        httpHeaders: AuthService.imageAuthHeaders,
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: (size * 3).round(),
        memCacheHeight: (size * 3).round(),
        placeholder: (_, _) => fallback(),
        errorWidget: (_, _, _) => fallback(),
      ),
    );
  }
}
