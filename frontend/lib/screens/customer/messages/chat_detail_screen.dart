import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:magang_titc/constants/app_colors.dart';
import 'package:magang_titc/models/message_model.dart';
import 'package:magang_titc/services/auth_service.dart';
import 'package:magang_titc/services/messages_service.dart';

class ChatDetailScreen extends StatefulWidget {
  final int threadId;
  final String title;
  final String avatarUrl;
  final bool canSendMessage;

  const ChatDetailScreen({
    super.key,
    required this.threadId,
    required this.title,
    required this.avatarUrl,
    this.canSendMessage = true,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _messageController = TextEditingController();
  late Future<ChatMessagesResult> _messagesFuture;
  bool _isSending = false;
  String? _sendError;

  @override
  void initState() {
    super.initState();
    _messagesFuture = MessagesService.fetchMessages(widget.threadId);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _messagesFuture = MessagesService.fetchMessages(widget.threadId);
    });
    await _messagesFuture;
  }

  Future<void> _send() async {
    final text = _messageController.text;
    if (text.trim().isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      _sendError = null;
    });

    try {
      await MessagesService.sendMessage(widget.threadId, text);
      _messageController.clear();
      await _refresh();
    } catch (e) {
      setState(() => _sendError = 'Gagal mengirim pesan: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 3,
        scrolledUnderElevation: 3,
        shadowColor: kShadowColor,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blue.shade50,
              backgroundImage: widget.avatarUrl.isNotEmpty ? CachedNetworkImageProvider(widget.avatarUrl, headers: AuthService.imageAuthHeaders) : null,
              child: widget.avatarUrl.isEmpty
                  ? Text(widget.title.isNotEmpty ? widget.title[0].toUpperCase() : '?')
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(color: Colors.black87, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<ChatMessagesResult>(
                future: _messagesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Center(child: Text('Gagal memuat: ${snapshot.error}')),
                        ),
                      ],
                    );
                  }

                  final messages = snapshot.data!.messages;
                  if (messages.isEmpty) {
                    return ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(child: Text('Belum ada pesan.')),
                        ),
                      ],
                    );
                  }

                  // API mengembalikan pesan terbaru duluan; balik urutan agar
                  // pesan terlama tampil di atas seperti chat pada umumnya.
                  final ordered = messages.reversed.toList();

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: ordered.length,
                    itemBuilder: (context, index) {
                      final message = ordered[index];
                      final isMine = message.authorUsername.isNotEmpty &&
                          message.authorUsername == AuthService.userSlug;
                      return _buildMessageBubble(message, isMine);
                    },
                  );
                },
              ),
            ),
          ),
          if (_sendError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(_sendError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
          if (widget.canSendMessage) _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel message, bool isMine) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.blue.shade50,
              backgroundImage: message.authorAvatar.isNotEmpty ? CachedNetworkImageProvider(message.authorAvatar, headers: AuthService.imageAuthHeaders) : null,
              child: message.authorAvatar.isEmpty
                  ? Text(message.authorName.isNotEmpty ? message.authorName[0].toUpperCase() : '?', style: const TextStyle(fontSize: 12))
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMine ? const Color(0xFF1E5AF5) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: isMine ? null : Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isMine)
                    Text(
                      message.authorName,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54),
                    ),
                  Text(
                    message.text,
                    style: TextStyle(color: isMine ? Colors.white : Colors.black87),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: kShadowDown,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Tulis pesan...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Color(0xFF1E5AF5)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _isSending ? null : _send,
              icon: _isSending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const PhosphorIcon(PhosphorIconsFill.paperPlaneTilt, color: Color(0xFF1E5AF5)),
            ),
          ],
        ),
      ),
    );
  }
}
