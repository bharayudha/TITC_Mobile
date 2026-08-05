import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:magang_titc/screens/main_shell.dart';
import 'package:magang_titc/constants/app_colors.dart';
import 'package:magang_titc/models/message_model.dart';
import 'package:magang_titc/services/messages_service.dart';
import 'package:magang_titc/screens/customer/preparation_test/preparation_test_webview_screen.dart';
import 'package:magang_titc/screens/customer/messages/chat_detail_screen.dart';
import 'package:magang_titc/widgets/customer/customer_bottom_nav_bar.dart';
import 'package:magang_titc/widgets/customer/side_drawer.dart';
import 'package:magang_titc/widgets/shared/top_app_bar.dart';

class MessagesListScreen extends StatefulWidget {
  const MessagesListScreen({super.key});

  @override
  State<MessagesListScreen> createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends State<MessagesListScreen> {
  final _searchController = TextEditingController();
  late Future<ChatThreadsResult> _threadsFuture;

  @override
  void initState() {
    super.initState();
    _threadsFuture = MessagesService.fetchThreads();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    if (index == 4) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PreparationTestWebviewScreen()),
      );
      return;
    }
    // Kembali ke shell utama pada tab yang dipilih, tanpa menumpuk halaman.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => MainShell(initialIndex: index)),
      (route) => false,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _threadsFuture = MessagesService.fetchThreads();
    });
    await _threadsFuture;
  }

  void _openThread(ChatThreadModel thread) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          threadId: thread.id,
          title: thread.title,
          avatarUrl: thread.avatarUrl,
          canSendMessage: thread.canSendMessage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const TitcAppBar(),
      drawer: const SideDrawer(),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Blok header + search dipisahkan dari daftar lewat drop shadow.
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: kShadowDown,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildMessagesHeader(),
                    _buildSearchBar(),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FutureBuilder<ChatThreadsResult>(
                future: _threadsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(child: Text('Gagal memuat: ${snapshot.error}')),
                    );
                  }

                  final result = snapshot.data!;
                  final query = _searchController.text.trim().toLowerCase();
                  final communities = _filterThreads(result.communityThreads, query);
                  final directs = _filterThreads([...result.directThreads, ...result.groupThreads], query);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSectionLabel('COMMUNITIES'),
                      const SizedBox(height: 12),
                      _buildThreadSection(communities, 'Belum ada percakapan komunitas.'),
                      const SizedBox(height: 24),
                      _buildSectionLabel('DIRECT MESSAGES'),
                      const SizedBox(height: 12),
                      _buildThreadSection(directs, 'Belum ada pesan langsung.'),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: -1,
        onTap: _onNavTap,
      ),
    );
  }

  List<ChatThreadModel> _filterThreads(List<ChatThreadModel> threads, String query) {
    if (query.isEmpty) return threads;
    return threads.where((t) => t.title.toLowerCase().contains(query)).toList();
  }

  Widget _buildMessagesHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'MESSAGES',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              IconButton(
                icon: const PhosphorIcon(
                  PhosphorIconsRegular.paperPlaneTilt,
                  color: Colors.black87,
                ),
                onPressed: _refresh,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search conversations',
          hintStyle: const TextStyle(color: Colors.grey),
          prefixIcon: const PhosphorIcon(
            PhosphorIconsRegular.magnifyingGlass,
            color: Colors.grey,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1E5AF5)),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildThreadSection(List<ChatThreadModel> threads, String emptyMessage) {
    if (threads.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FC),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(emptyMessage, style: TextStyle(color: Colors.grey.shade600)),
        ),
      );
    }

    return Column(
      children: threads.map(_buildThreadTile).toList(),
    );
  }

  Widget _buildThreadTile(ChatThreadModel thread) {
    return InkWell(
      onTap: () => _openThread(thread),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.blue.shade50,
              backgroundImage: thread.avatarUrl.isNotEmpty ? CachedNetworkImageProvider(thread.avatarUrl) : null,
              child: thread.avatarUrl.isEmpty
                  ? Text(thread.title.isNotEmpty ? thread.title[0].toUpperCase() : '?')
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    thread.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (thread.lastMessagePreview.isNotEmpty)
                    Text(
                      thread.lastMessagePreview,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (thread.unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E5AF5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${thread.unreadCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
