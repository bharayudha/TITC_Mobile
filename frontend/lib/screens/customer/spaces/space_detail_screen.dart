import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:magang_titc/models/activity_model.dart';
import 'package:magang_titc/models/space_model.dart';
import 'package:magang_titc/services/api_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:magang_titc/screens/customer/spaces/post_detail_screen.dart';
import 'package:magang_titc/screens/shared/authenticated_webview_screen.dart';

class SpaceDetailScreen extends StatefulWidget {
  final SpaceModel space;

  const SpaceDetailScreen({super.key, required this.space});

  @override
  State<SpaceDetailScreen> createState() => _SpaceDetailScreenState();
}

class _SpaceDetailScreenState extends State<SpaceDetailScreen> {
  late Future<List<ActivityModel>> _feedsFuture;

  @override
  void initState() {
    super.initState();
    _feedsFuture = ApiService.fetchSpaceFeeds(widget.space.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2124), // Tampilan dark mode menyerupai web
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _feedsFuture = ApiService.fetchSpaceFeeds(widget.space.id);
          });
          await _feedsFuture;
        },
        child: FutureBuilder<List<ActivityModel>>(
          future: _feedsFuture,
          builder: (context, snapshot) {
            final feeds = snapshot.data ?? [];
            final isLoading = snapshot.connectionState == ConnectionState.waiting;
            final hasError = snapshot.hasError;

            return CustomScrollView(
              slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(
                  child: _buildSpaceHeader(),
                ),
                if (isLoading)
                  const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
                if (hasError)
                  SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text('Gagal memuat feed', style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  ),
                if (!isLoading && !hasError) ...[
                  SliverToBoxAdapter(
                    child: _buildSidebarCards(feeds),
                  ),
                  _buildFeedsList(feeds),
                ],
                // Jarak bawah
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: const Color(0xFF2B2E33),
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        background: widget.space.coverPhotoUrl.isNotEmpty
            ? CachedNetworkImage(imageUrl: widget.space.coverPhotoUrl, fit: BoxFit.cover)
            : Container(color: Colors.grey.shade800),
      ),
    );
  }

  Widget _buildSpaceHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  image: widget.space.logoUrl.isNotEmpty
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(widget.space.logoUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: widget.space.logoUrl.isEmpty ? const Icon(Icons.group, size: 32) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.space.title,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.space.privacy} • ${widget.space.membersCount} members',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Invite / Joined button
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Invite'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.check, size: 18, color: Colors.white),
                label: const Text('Joined', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarCards(List<ActivityModel> feeds) {
    // Ambil feed pertama untuk Recent Activity
    ActivityModel? recentActivity;
    if (feeds.isNotEmpty) {
      recentActivity = feeds.first;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // About Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2B2E33),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('About', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Text(
                  widget.space.description.replaceAll(RegExp(r'<[^>]*>'), ''),
                  style: TextStyle(color: Colors.grey.shade300, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.public, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.space.privacy, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                          Text('Any site member can see who\'s in the Space and what they post.', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Recent Space Activities
          if (recentActivity != null)
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PostDetailScreen(
                      post: recentActivity!,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B2E33),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Recent Space Activities', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.shade600,
                            image: recentActivity.avatarUrl.isNotEmpty
                              ? DecorationImage(image: CachedNetworkImageProvider(recentActivity.avatarUrl), fit: BoxFit.cover)
                              : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                                  children: [
                                    TextSpan(text: recentActivity.authorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const TextSpan(text: ' published a new status '),
                                    TextSpan(text: widget.space.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(recentActivity.date, style: TextStyle(color: Colors.blue.shade400, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeedsList(List<ActivityModel> feeds) {
    if (feeds.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: Text('Belum ada feed di space ini.', style: TextStyle(color: Colors.grey)),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final feed = feeds[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      backgroundImage: feed.avatarUrl.isNotEmpty ? CachedNetworkImageProvider(feed.avatarUrl) : null,
                      backgroundColor: Colors.grey,
                      child: feed.avatarUrl.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(feed.authorName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          Text(
                            feed.date,
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  feed.content.replaceAll(RegExp(r'<[^>]*>'), '').trim(),
                  style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                ),
                
                // Link Preview
                if (feed.linkPreviewUrl != null && feed.linkPreviewUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AuthenticatedWebViewScreen(
                            url: feed.linkPreviewUrl!,
                            title: feed.linkPreviewTitle ?? 'Web Link',
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2124),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade800),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Kita tidak selalu punya gambar thumbnail, cukup tampilkan teks link
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  feed.linkPreviewTitle?.isNotEmpty == true ? feed.linkPreviewTitle! : 'External Link',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                if (feed.linkPreviewDescription != null && feed.linkPreviewDescription!.isNotEmpty)
                                  Text(
                                    feed.linkPreviewDescription!,
                                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 8),
                                Text(
                                  feed.linkPreviewUrl!,
                                  style: TextStyle(color: Colors.blue.shade300, fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                Divider(color: Colors.grey.shade700),
                Row(
                  children: [
                    Icon(PhosphorIconsRegular.heart, color: Colors.grey.shade400, size: 18),
                    const SizedBox(width: 8),
                    Text('${feed.likeCount} likes', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                    const SizedBox(width: 24),
                    Icon(PhosphorIconsRegular.chatCircle, color: Colors.grey.shade400, size: 18),
                    const SizedBox(width: 8),
                    Text('${feed.commentCount} comments', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                  ],
                )
              ],
            ),
          );
        },
        childCount: feeds.length,
      ),
    );
  }
}
