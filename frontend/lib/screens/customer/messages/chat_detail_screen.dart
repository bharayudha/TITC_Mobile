import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

class _ChatDetailScreenState extends State<ChatDetailScreen>
    with WidgetsBindingObserver {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  /// Pesan disimpan di state, BUKAN di dalam `Future` yang dipakai
  /// `FutureBuilder`. Dengan `FutureBuilder`, setiap polling membuat Future
  /// baru sehingga layar kembali ke keadaan loading — spinner berkedip tiap
  /// beberapa detik dan posisi gulir melompat ke atas.
  List<ChatMessageModel> _messages = const [];
  bool _isLoading = true;
  String? _loadError;

  Timer? _pollTimer;
  bool _isSending = false;
  String? _sendError;

  /// Jeda polling. Web memakai pola yang sama (terlihat dari request
  /// `new?last_id=` di DevTools). Dipilih 6 detik: cukup terasa seketika
  /// untuk percakapan, tapi tidak menghujani server TITC yang memang lambat
  /// (toleransi timeout-nya saja 30 detik).
  static const _pollInterval = Duration(seconds: 6);

  /// Gambar yang sudah dipilih tapi belum ikut terkirim.
  ///
  /// Disimpan sebagai berkas lokal, BUKAN langsung diunggah saat dipilih:
  /// user masih bisa membatalkannya, dan mengunggah lebih dulu berarti
  /// meninggalkan berkas yatim di server setiap kali batal.
  File? _pickedImage;
  bool _isUploading = false;

  /// Pesan yang sedang dibalas. Null berarti kiriman biasa.
  ChatMessageModel? _replyTarget;

  /// Pilihan emoji reaksi. Dibatasi enam yang lazim, bukan pemilih emoji
  /// penuh: menekan lama lalu memilih dari ratusan emoji jauh lebih lambat
  /// daripada sekali ketuk, dan reaksi memang dipakai untuk merespons cepat.
  static const _reactionChoices = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInitial();
    _startPolling();
  }

  @override
  void dispose() {
    // Timer WAJIB dimatikan: kalau tidak, ia terus menembak server setelah
    // layar ditutup dan `setState` dipanggil pada State yang sudah mati.
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Hentikan polling saat app tidak di layar, lanjutkan saat kembali.
  ///
  /// Tanpa ini app tetap menembak server tiap 6 detik walau ada di latar
  /// belakang — boros baterai dan kuota untuk sesuatu yang tidak dilihat
  /// siapa pun.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _poll();
      _startPolling();
    } else {
      _pollTimer?.cancel();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  Future<void> _loadInitial() async {
    try {
      final result = await MessagesService.fetchMessages(widget.threadId);
      if (!mounted) return;
      setState(() {
        _messages = result.messages;
        _isLoading = false;
      });
      // Chat dibuka pada pesan TERBARU, bukan yang paling lama. Tanpa ini
      // pesan yang baru masuk mendarat di bawah layar tanpa terlihat.
      _jumpToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = '$e';
        _isLoading = false;
      });
    }
  }

  /// Ambil pesan terbaru diam-diam.
  ///
  /// Berbeda dari [_loadInitial]: tidak menyalakan indikator loading dan
  /// tidak menampilkan error. Gangguan jaringan sesaat tidak boleh
  /// mengosongkan percakapan yang sedang dibaca — cukup dicoba lagi pada
  /// putaran berikutnya.
  Future<void> _poll({bool full = false}) async {
    if (!mounted) return;
    try {
      final latest = await _fetchLatest(full: full);
      if (!mounted || !_hasNewMessages(latest)) return;

      // Diperiksa SEBELUM daftar diperbarui: setelah itu posisi gulir sudah
      // bergeser oleh isi baru dan jawabannya tidak lagi bermakna.
      final wasAtBottom = _isNearBottom;
      setState(() => _messages = latest);

      // Hanya digulir kalau user memang sedang di bawah. Kalau dia sedang
      // membaca riwayat ke atas, menyeretnya ke bawah setiap ada pesan baru
      // membuat riwayat mustahil dibaca.
      if (wasAtBottom) _scrollToBottom();
    } catch (_) {
      // Sengaja diabaikan — lihat penjelasan di atas.
    }
  }

  /// Daftar pesan terkini.
  ///
  /// Jalur cepat memakai endpoint inkremental (`/new?last_id=`) yang hanya
  /// mengirim pesan setelah id tertentu — ini yang dipakai web, dan jauh
  /// lebih ringan daripada menarik ulang percakapan panjang tiap 6 detik.
  ///
  /// Jatuh ke penarikan penuh kalau [full] diminta, kalau belum ada pesan
  /// sama sekali, atau kalau endpoint inkremental gagal/bentuknya tak
  /// dikenali. Jadi kegagalan optimasi cuma bikin boros — tidak pernah
  /// membuat chat berhenti berfungsi.
  Future<List<ChatMessageModel>> _fetchLatest({bool full = false}) async {
    final lastId = _messages.isEmpty ? 0 : _messages.first.id;

    if (!full && lastId > 0) {
      try {
        final incoming = await MessagesService.fetchNewMessages(
          widget.threadId,
          lastId,
        );
        if (incoming.isEmpty) return _messages;
        return _mergeById(incoming);
      } catch (_) {
        // Lanjut ke penarikan penuh di bawah.
      }
    }

    return (await MessagesService.fetchMessages(widget.threadId)).messages;
  }

  /// Gabungkan pesan baru dengan yang sudah ada, dedupe lalu urutkan
  /// berdasarkan id menurun.
  ///
  /// Diurutkan sendiri, bukan sekadar disisipkan di depan: urutan balasan
  /// endpoint inkremental belum terverifikasi, dan mengurutkan by id membuat
  /// hasilnya benar tanpa perlu bergantung pada asumsi itu.
  List<ChatMessageModel> _mergeById(List<ChatMessageModel> incoming) {
    final byId = <int, ChatMessageModel>{
      for (final message in _messages) message.id: message,
      // Versi dari server ditaruh belakangan supaya menimpa salinan lama
      // kalau isinya sempat berubah.
      for (final message in incoming) message.id: message,
    };
    return byId.values.toList()..sort((a, b) => b.id.compareTo(a.id));
  }

  /// Bandingkan jumlah dan id pesan terakhir. Membandingkan panjang saja
  /// tidak cukup: pesan bisa dihapus dan diganti yang baru pada jeda yang
  /// sama, sehingga jumlahnya kebetulan tetap.
  bool _hasNewMessages(List<ChatMessageModel> incoming) {
    if (identical(incoming, _messages)) return false;
    if (incoming.length != _messages.length) return true;
    if (incoming.isEmpty) return false;
    return incoming.first.id != _messages.first.id;
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels < 120;
  }

  /// Gulir ke pesan terbaru. Ditunda satu frame karena tinggi daftar baru
  /// diketahui setelah isi barunya selesai digambar.
  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  void _jumpToBottom() => _scrollToBottom(animate: false);

  /// Tarik ke bawah = penarikan PENUH, bukan inkremental.
  ///
  /// Endpoint inkremental hanya mengirim pesan baru, jadi ia tidak akan
  /// pernah menyadari pesan yang dihapus atau disunting di web. Saat user
  /// menarik untuk menyegarkan, yang dia minta memang gambaran terbaru yang
  /// utuh.
  Future<void> _refresh() async {
    await _poll(full: true);
  }

  /// Menu aksi pesan, muncul saat gelembung ditekan lama — meniru menu ⋮
  /// di web (Reply / Delete) ditambah baris reaksi cepat.
  void _showMessageActions(ChatMessageModel message, bool isMine) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final emoji in _reactionChoices)
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _react(message, emoji);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const PhosphorIcon(PhosphorIconsRegular.arrowBendUpLeft),
              title: const Text('Balas'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                setState(() => _replyTarget = message);
              },
            ),
            // Hapus hanya ditawarkan untuk pesan sendiri. Menampilkannya pada
            // pesan orang lain berarti menjanjikan sesuatu yang kemungkinan
            // besar ditolak server — lebih baik tidak ada daripada ada tapi
            // gagal.
            if (isMine)
              ListTile(
                leading: const PhosphorIcon(
                  PhosphorIconsRegular.trash,
                  color: Colors.red,
                ),
                title: const Text('Hapus', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _confirmDelete(message);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _react(ChatMessageModel message, String emoji) async {
    try {
      await MessagesService.reactToMessage(message.id, emoji);
      await _poll(full: true);
    } catch (e) {
      if (mounted) setState(() => _sendError = '$e');
    }
  }

  /// Menghapus pesan tidak bisa dibatalkan, jadi selalu dikonfirmasi dulu —
  /// apalagi menu ini muncul dari tekan lama, yang bisa terpicu tak sengaja.
  Future<void> _confirmDelete(ChatMessageModel message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus pesan?'),
        content: const Text('Pesan ini akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await MessagesService.deleteMessage(message.id);
      // WAJIB penarikan penuh: endpoint inkremental hanya mengirim pesan
      // BARU, jadi ia tidak akan pernah tahu ada yang hilang.
      await _poll(full: true);
    } catch (e) {
      if (mounted) setState(() => _sendError = '$e');
    }
  }

  Future<void> _pickImage() async {
    // Dibatasi 1600px & kualitas 85 seperti upload avatar: foto kamera HP
    // bisa 4000px lebih, dan mengunggahnya utuh lambat di jaringan seluler
    // tanpa terlihat lebih baik di gelembung chat.
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _pickedImage = File(picked.path);
      _sendError = null;
    });
  }

  Future<void> _send() async {
    final text = _messageController.text;
    final image = _pickedImage;

    // Gambar saja tanpa teks tetap sah, jadi yang dicegah cuma kalau
    // dua-duanya kosong.
    if ((text.trim().isEmpty && image == null) || _isSending) return;

    setState(() {
      _isSending = true;
      _isUploading = image != null;
      _sendError = null;
    });

    try {
      // Unggah baru dilakukan di sini, bukan saat gambar dipilih — supaya
      // membatalkan pilihan tidak meninggalkan berkas yatim di server.
      final mediaItems = <String>[];
      if (image != null) {
        mediaItems.add(
          await MessagesService.uploadMedia(widget.threadId, image),
        );
      }
      if (mounted) setState(() => _isUploading = false);

      final reply = _replyTarget;
      await MessagesService.sendMessage(
        widget.threadId,
        text,
        mediaItems: mediaItems,
        replyToId: reply?.id,
        // Web mengirim ulang cuplikan pesan yang dibalas. Untuk balasan ke
        // pesan gambar (yang teksnya kosong) dipakai kata "Gambar" supaya
        // kutipannya tidak tampil kosong melompong.
        replyText: reply == null
            ? null
            : (reply.text.isNotEmpty
                  ? reply.text
                  : (reply.mediaUrls.isNotEmpty ? 'Gambar' : '')),
      );
      _messageController.clear();
      _pickedImage = null;
      _replyTarget = null;
      await _poll();
      // Selalu digulir ke bawah setelah MENGIRIM, tanpa syarat posisi gulir.
      // Orang yang baru menekan kirim pasti ingin melihat pesannya sendiri —
      // ini beda dari pesan masuk, yang tidak boleh menyeret paksa.
      _scrollToBottom();
    } catch (e) {
      // Gambar yang dipilih sengaja TIDAK dibuang saat gagal: kalau
      // penyebabnya jaringan, user tinggal menekan kirim lagi tanpa harus
      // mencari ulang fotonya di galeri.
      setState(() => _sendError = 'Gagal mengirim pesan: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _isUploading = false;
        });
      }
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
              backgroundImage: widget.avatarUrl.isNotEmpty
                  ? CachedNetworkImageProvider(
                      widget.avatarUrl,
                      headers: AuthService.imageAuthHeaders,
                    )
                  : null,
              child: widget.avatarUrl.isEmpty
                  ? Text(
                      widget.title.isNotEmpty
                          ? widget.title[0].toUpperCase()
                          : '?',
                    )
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
              child: _buildMessageList(),
            ),
          ),
          if (_sendError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                _sendError!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          if (widget.canSendMessage) _buildComposer(),
        ],
      ),
    );
  }

  /// Format jam pesan seperti web ("11:53 AM") — bukan waktu relatif
  /// ("x minutes ago") seperti `_humanizeTime` di layar Members, karena web
  /// menampilkan jam-menit apa adanya, bukan selisih waktu. Ditulis manual
  /// (bukan lewat package `intl`) karena `intl` belum jadi dependency di
  /// proyek ini dan formatnya sederhana.
  String _formatMessageTime(String raw) {
    final parsed = DateTime.tryParse(raw.trim().replaceFirst(' ', 'T'));
    if (parsed == null) return '';
    final hour24 = parsed.hour;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final period = hour24 < 12 ? 'AM' : 'PM';
    return '$hour12:$minute $period';
  }

  Widget _buildMessageBubble(ChatMessageModel message, bool isMine) {
    return GestureDetector(
      // Tekan lama, bukan ketuk: ketuk sudah dipakai membuka gambar, dan
      // tekan lama adalah kebiasaan yang sudah dikenal di aplikasi chat.
      onLongPress: () => _showMessageActions(message, isMine),
      child: _buildBubbleContent(message, isMine),
    );
  }

  Widget _buildBubbleContent(ChatMessageModel message, bool isMine) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.blue.shade50,
              backgroundImage: message.authorAvatar.isNotEmpty
                  ? CachedNetworkImageProvider(
                      message.authorAvatar,
                      headers: AuthService.imageAuthHeaders,
                    )
                  : null,
              child: message.authorAvatar.isEmpty
                  ? Text(
                      message.authorName.isNotEmpty
                          ? message.authorName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontSize: 12),
                    )
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
                border: isMine
                    ? null
                    : Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isMine)
                    Text(
                      message.authorName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                  if (message.replyText != null &&
                      message.replyText!.isNotEmpty) ...[
                    _buildReplyQuote(message.replyText!, isMine),
                    const SizedBox(height: 6),
                  ],
                  for (final url in message.mediaUrls) ...[
                    _buildMessageImage(url),
                    const SizedBox(height: 6),
                  ],
                  // Pesan yang isinya cuma gambar tidak menyisakan baris teks
                  // kosong yang memperlebar gelembung tanpa alasan.
                  if (message.text.isNotEmpty)
                    Text(
                      message.text,
                      style: TextStyle(
                        color: isMine ? Colors.white : Colors.black87,
                      ),
                    ),
                  if (message.reactions.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _buildReactions(message, isMine),
                  ],
                  // Jam diletakkan DI DALAM gelembung. `Align` sempat
                  // dipakai untuk rata-kanan, TAPI itu memaksa Align (dan
                  // ikut menyeret Column + Container gelembung) melebar
                  // penuh mengikuti constraint terluas dari `Flexible`,
                  // bukan menyesuaikan isi teks — gelembung pendek seperti
                  // "tes"/"p" jadi selebar layar. Diganti `Text` polos
                  // (rata kiri, sejajar isi pesan) supaya gelembung kembali
                  // menyusut sesuai panjang teksnya sendiri.
                  const SizedBox(height: 4),
                  Text(
                    _formatMessageTime(message.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMine ? Colors.white70 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Semua keadaan di bawah memakai ListView, bukan Center, supaya
    // pull-to-refresh tetap bisa dipakai saat percakapan kosong atau gagal
    // dimuat — justru saat itulah user paling ingin mencoba lagi.
    if (_loadError != null) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(child: Text('Gagal memuat: $_loadError')),
          ),
        ],
      );
    }

    if (_messages.isEmpty) {
      return ListView(
        children: const [
          Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('Belum ada pesan.')),
          ),
        ],
      );
    }

    // API mengembalikan pesan terbaru duluan; balik urutan agar pesan
    // terlama tampil di atas seperti chat pada umumnya.
    final ordered = _messages.reversed.toList();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: ordered.length,
      itemBuilder: (context, index) {
        final message = ordered[index];
        final isMine =
            message.authorUsername.isNotEmpty &&
            message.authorUsername == AuthService.userSlug;
        return _buildMessageBubble(message, isMine);
      },
    );
  }

  /// Kutipan pesan yang dibalas, tampil di atas isi pesan seperti di web.
  Widget _buildReplyQuote(String quoted, bool isMine) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        // Di dalam gelembung biru dipakai putih transparan, di gelembung
        // putih dipakai abu — supaya kutipannya tetap terbaca di keduanya.
        color: isMine ? Colors.white24 : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMine ? Colors.white70 : const Color(0xFF1E5AF5),
            width: 3,
          ),
        ),
      ),
      child: Text(
        quoted,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: isMine ? Colors.white70 : Colors.black54,
        ),
      ),
    );
  }

  /// Deretan reaksi di bawah isi pesan, mis. `👍 2`.
  Widget _buildReactions(ChatMessageModel message, bool isMine) {
    return Wrap(
      spacing: 4,
      children: [
        for (final entry in message.reactions.entries)
          InkWell(
            // Diketuk untuk ikut bereaksi dengan emoji yang sama — server
            // yang memutuskan itu menambah atau membatalkan.
            onTap: () => _react(message, entry.key),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isMine
                    ? Colors.white24
                    : Colors.black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${entry.key} ${entry.value}',
                style: TextStyle(
                  fontSize: 11,
                  color: isMine ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Gambar di dalam gelembung pesan. Diketuk untuk melihat versi penuh.
  Widget _buildMessageImage(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: GestureDetector(
        onTap: () => _openImageViewer(url),
        // Dibatasi supaya gambar potret yang sangat tinggi tidak memenuhi
        // layar dan menenggelamkan pesan lain di sekitarnya.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260, maxWidth: 240),
          child: CachedNetworkImage(
            imageUrl: url,
            // Sebagian media FCOM ada di balik privacy WordPress, sama seperti
            // call site gambar lain di app ini.
            httpHeaders: AuthService.imageAuthHeaders,
            fit: BoxFit.cover,
            // Thumbnail dibatasi maxHeight/maxWidth 260/240 di atas — decode
            // di memori tidak perlu lebih dari itu. Gambar penuh (pinch-zoom,
            // lihat `_openImageViewer`) SENGAJA tidak dibatasi di sini.
            memCacheWidth: 720,
            memCacheHeight: 780,
            placeholder: (_, _) => Container(
              width: 160,
              height: 120,
              color: Colors.black12,
              child: const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            errorWidget: (_, _, _) => Container(
              width: 160,
              height: 120,
              color: Colors.black12,
              child: const Icon(Icons.broken_image, color: Colors.black38),
            ),
          ),
        ),
      ),
    );
  }

  /// Tampilkan gambar ukuran penuh, bisa dicubit untuk memperbesar.
  void _openImageViewer(String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: CachedNetworkImage(
                imageUrl: url,
                httpHeaders: AuthService.imageAuthHeaders,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bar "membalas" di atas kotak ketik.
  ///
  /// Tanpa ini tidak ada tanda apa pun bahwa kiriman berikutnya akan menjadi
  /// balasan — dan tidak ada cara membatalkannya.
  Widget _buildReplyBar() {
    final target = _replyTarget!;
    final preview = target.text.isNotEmpty
        ? target.text
        : (target.mediaUrls.isNotEmpty ? 'Gambar' : '');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3F8),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: Color(0xFF1E5AF5), width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Membalas ${target.authorName}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E5AF5),
                  ),
                ),
                if (preview.isNotEmpty)
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _replyTarget = null),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 16, color: Colors.black45),
            ),
          ),
        ],
      ),
    );
  }

  /// Pratinjau gambar yang menunggu dikirim, lengkap dengan tombol batal.
  ///
  /// Tanpa ini user tidak punya cara membatalkan salah pilih selain menutup
  /// layar chat — dan tidak ada tanda apa pun bahwa gambar akan ikut terkirim.
  Widget _buildImagePreview() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                _pickedImage!,
                width: 84,
                height: 84,
                fit: BoxFit.cover,
              ),
            ),
            if (_isUploading)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: -6,
              right: -6,
              child: GestureDetector(
                // Dimatikan selama pengiriman: membuang gambar di tengah
                // unggahan hanya bikin status di layar tidak cocok dengan
                // apa yang sedang berjalan.
                onTap: _isSending
                    ? null
                    : () => setState(() => _pickedImage = null),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: _isSending ? Colors.black26 : Colors.black87,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 13, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyTarget != null) _buildReplyBar(),
            if (_pickedImage != null) _buildImagePreview(),
            Row(
              children: [
                // Ikon gambar di kiri, mengikuti tata letak composer web.
                IconButton(
                  onPressed: _isSending ? null : _pickImage,
                  tooltip: 'Kirim gambar',
                  icon: PhosphorIcon(
                    PhosphorIconsRegular.image,
                    color: _isSending ? Colors.black26 : Colors.black54,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Tulis pesan...',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
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
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const PhosphorIcon(
                          PhosphorIconsFill.paperPlaneTilt,
                          color: Color(0xFF1E5AF5),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
