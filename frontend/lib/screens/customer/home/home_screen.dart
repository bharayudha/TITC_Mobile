import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:magang_titc/widgets/shared/section_header.dart';
import '../../../models/activity_model.dart';
import '../../../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<ActivityModel>> _activitiesFuture;

  @override
  void initState() {
    super.initState();
    _activitiesFuture = ApiService.fetchActivities();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _activitiesFuture = ApiService.fetchActivities();
        });
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Shortcut Menus (Mock)
          SizedBox(
            height: 90,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildShortcutItem('TOEFL ITP', PhosphorIconsRegular.fileText),
                _buildShortcutItem('Prep Test', PhosphorIconsRegular.desktop),
                _buildShortcutItem('Readiness', PhosphorIconsRegular.checkCircle),
                _buildShortcutItem('Tracking', PhosphorIconsRegular.mapPin),
                _buildShortcutItem('Placement', PhosphorIconsRegular.student),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // 2. Promo Banner (Mock)
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: Colors.blue.shade900,
              borderRadius: BorderRadius.circular(12),
              image: const DecorationImage(
                image: NetworkImage('https://titc.or.id/wp-content/uploads/2025/07/cropped-TORC.png'), // Placeholder
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
              ),
            ),
            child: const Center(
              child: Text(
                'COMING SOON\nTOEFL iBT',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 3. Header Feed
          SectionHeader(
            title: 'Feed',
            trailing: IconButton(
              icon: const PhosphorIcon(PhosphorIconsRegular.dotsThreeVertical, color: Colors.black54),
              onPressed: () {},
            ),
          ),
          const SizedBox(height: 8),
          
          // 4. Activity Feed (FutureBuilder)
          FutureBuilder<List<ActivityModel>>(
            future: _activitiesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('Belum ada aktivitas.'));
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final activity = snapshot.data![index];
                  return _buildActivityCard(activity);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutItem(String title, IconData icon) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue.shade50,
            radius: 24,
            child: PhosphorIcon(icon, color: Colors.blue.shade700),
          ),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildActivityCard(ActivityModel activity) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: activity.avatarUrl.isNotEmpty ? NetworkImage(activity.avatarUrl) : null,
                  child: activity.avatarUrl.isEmpty ? Text(activity.authorName[0]) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(activity.authorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (activity.date.isNotEmpty)
                        Text(activity.date.split('T')[0], style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              // Simple strip HTML
              activity.content.replaceAll(RegExp(r'<[^>]*>'), ''),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                PhosphorIcon(PhosphorIconsRegular.heart, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text('${activity.likeCount}', style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(width: 16),
                PhosphorIcon(PhosphorIconsRegular.chatCircle, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text('${activity.commentCount}', style: TextStyle(color: Colors.grey.shade600)),
              ],
            )
          ],
        ),
      ),
    );
  }
}
