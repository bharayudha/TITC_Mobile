import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:magang_titc/constants/app_colors.dart';
import 'package:magang_titc/models/space_model.dart';
import 'package:magang_titc/services/api_service.dart';

/// Hasil dari overlay pencarian.
///
/// Bentuknya mengikuti pencarian di portal web: yang dicari adalah POST, dan
/// cakupannya dipilih per Space — bukan mencari daftar space/course/member.
class SearchRequest {
  const SearchRequest({
    required this.query,
    this.spaceSlug = '',
    this.spaceLabel = 'All Posts',
    this.includeComments = false,
  });

  final String query;

  /// Kosong berarti "All Posts", sesuai parameter `space=` di API.
  final String spaceSlug;

  /// Nama space untuk ditampilkan di layar hasil.
  final String spaceLabel;

  /// Centang "Comments" — ikut mencari di dalam komentar.
  final bool includeComments;
}

/// Menampilkan mode pencarian: bilah pencarian menimpa app bar, sementara
/// seluruh konten di belakangnya diredupkan. Ditutup dengan menekan panah
/// kembali, mengetuk area redup, atau tombol back perangkat.
///
/// Mengembalikan [SearchRequest] saat user menekan enter, atau `null` kalau
/// pencarian dibatalkan.
Future<SearchRequest?> showSearchOverlay(BuildContext context) {
  return showGeneralDialog<SearchRequest>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Tutup pencarian',
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) {
      return const SearchOverlay();
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

/// Bilah pencarian yang menempel di atas layar saat mode pencarian aktif.
class SearchOverlay extends StatefulWidget {
  const SearchOverlay({super.key});

  @override
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay> {
  final _controller = TextEditingController();

  /// Slug space terpilih; kosong = All Posts.
  String _spaceSlug = '';
  String _spaceLabel = 'All Posts';
  bool _includeComments = false;

  /// Isi dropdown: Membership Areas, sama seperti portal web. Diambil dari
  /// API (`/spaces/discover?type=all`), bukan di-hardcode, supaya space yang
  /// ditambah admin ikut muncul sendiri — termasuk yang belum di-join user.
  List<SpaceModel> _spaces = ApiService.cachedSpaces ?? const [];

  @override
  void initState() {
    super.initState();
    if (_spaces.isEmpty) {
      // Kegagalan sengaja diabaikan: dropdown tetap bisa dipakai untuk
      // "All Posts" walau daftarnya gagal dimuat.
      ApiService.fetchSpaces()
          .then((spaces) {
            if (mounted) setState(() => _spaces = spaces);
          })
          .catchError((_) {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Tutup tanpa hasil (tombol panah kembali / ketuk area redup).
  void _cancel() => Navigator.of(context).pop();

  /// Tutup sambil mengirim kata kunci. Kata kunci kosong diperlakukan sebagai
  /// pembatalan supaya tidak membuka layar hasil yang pasti kosong.
  void _submit(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _cancel();
      return;
    }
    Navigator.of(context).pop(
      SearchRequest(
        query: trimmed,
        spaceSlug: _spaceSlug,
        spaceLabel: _spaceLabel,
        includeComments: _includeComments,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: kShadowDown,
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildSearchField()),
                      const SizedBox(width: 8),
                      _buildScopeButton(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _buildSearchInRow(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        border: Border.all(color: onSurface.withValues(alpha: 0.8), width: 1.5),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          IconButton(
            icon: PhosphorIcon(
              PhosphorIconsRegular.arrowLeft,
              color: onSurface.withValues(alpha: 0.8),
            ),
            onPressed: _cancel,
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              // Keyboard langsung terbuka begitu mode pencarian aktif.
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: _submit,
              decoration: InputDecoration(
                // Meniru web: menunjukkan cakupan yang sedang aktif.
                hintText: _spaceSlug.isEmpty
                    ? 'Search for anything...'
                    : 'Search in #$_spaceSlug',
                hintStyle: TextStyle(
                  color: onSurface.withValues(alpha: 0.6),
                  fontSize: 16,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isCollapsed: true,
              ),
              style: TextStyle(fontSize: 16, color: onSurface),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  /// Dropdown cakupan: "All Posts" di paling atas, lalu daftar Membership
  /// Areas — susunan yang sama dengan portal web.
  Widget _buildScopeButton() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return PopupMenuButton<String>(
      tooltip: 'Cakupan pencarian',
      color: Theme.of(context).colorScheme.surface,
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(maxHeight: 400, minWidth: 220),
      onSelected: (slug) => setState(() {
        _spaceSlug = slug;
        _spaceLabel = slug.isEmpty ? 'All Posts' : _titleForSlug(slug);
      }),
      itemBuilder: (context) => [
        const PopupMenuItem<String>(value: '', child: Text('All Posts')),
        ..._buildGroup('Membership Areas', {
          for (final space in _spaces) space.slug: space.title,
        }),
      ],
      child: ConstrainedBox(
        // Judul space bisa panjang; dibatasi supaya tidak mendesak kotak
        // pencarian sampai tidak terbaca.
        constraints: const BoxConstraints(maxWidth: 110),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _spaceLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: onSurface.withValues(alpha: 0.8),
                ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: onSurface.withValues(alpha: 0.8),
            ),
          ],
        ),
      ),
    );
  }

  String _titleForSlug(String slug) {
    for (final space in _spaces) {
      if (space.slug == slug) return space.title;
    }
    return slug;
  }

  /// Satu kelompok berlabel di dalam dropdown. Kelompok kosong tidak
  /// menghasilkan apa-apa, jadi labelnya tidak menggantung tanpa isi saat
  /// daftarnya gagal dimuat.
  List<PopupMenuEntry<String>> _buildGroup(
    String label,
    Map<String, String> titlesBySlug,
  ) {
    if (titlesBySlug.isEmpty) return const [];
    return [
      const PopupMenuDivider(),
      PopupMenuItem<String>(
        enabled: false,
        height: 32,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
      for (final entry in titlesBySlug.entries)
        PopupMenuItem<String>(
          value: entry.key,
          child: Text(entry.value, overflow: TextOverflow.ellipsis),
        ),
    ];
  }

  /// Baris "Search in:" — meniru web. Post Title & Content selalu aktif
  /// (itu perilaku default server), Comments opsional.
  Widget _buildSearchInRow() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        Text(
          'Search in:',
          style: TextStyle(
            fontSize: 13,
            color: onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.check_box, size: 18, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(
          'Post Title & Content',
          style: TextStyle(
            fontSize: 13,
            color: onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(width: 12),
        InkWell(
          onTap: () => setState(() => _includeComments = !_includeComments),
          child: Row(
            children: [
              Icon(
                _includeComments
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: 18,
                color: _includeComments
                    ? AppColors.primary
                    : onSurface.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 4),
              Text(
                'Comments',
                style: TextStyle(
                  fontSize: 13,
                  color: onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
