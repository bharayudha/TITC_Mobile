import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:magang_titc/models/space_model.dart';
import 'package:magang_titc/services/api_service.dart';
import 'package:magang_titc/services/auth_service.dart';
import 'package:magang_titc/widgets/shared/admin_only.dart';
import 'package:magang_titc/screens/customer/spaces/space_webview_screen.dart';
import 'package:magang_titc/screens/shared/authenticated_webview_screen.dart';

/// Konten tab Spaces. App bar, drawer, chat FAB, dan bottom nav dipasang oleh
/// [MainShell].
class SpacesListScreen extends StatefulWidget {
  const SpacesListScreen({super.key});

  @override
  State<SpacesListScreen> createState() => _SpacesListScreenState();
}

class _SpacesListScreenState extends State<SpacesListScreen> {
  bool _showAllSpaces = true;
  late Future<List<SpaceModel>> _spacesFuture;
  List<SpaceModel> _allFetchedSpaces = [];
  String _searchQuery = '';
  String _sortBy = 'Alphabetical'; // Default sort
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadSpaces(useCache: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  /// Pencarian dikirim ke server, bukan disaring di HP. Filter lokal hanya
  /// menemukan space yang kebetulan sudah termuat, sedangkan di web semuanya
  /// dicari di server.
  ///
  /// Diberi jeda 450ms (sama seperti layar Members) supaya tiap huruf yang
  /// diketik tidak memicu satu request ke server TITC yang memang lambat.
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      final query = value.trim();
      if (query == _searchQuery) return;
      _searchQuery = query;
      _loadSpaces();
    });
  }

  /// Muat daftar spaces. Kalau [useCache] true dan ada data lama, data itu
  /// langsung ditampilkan (tidak loading dari nol tiap kali tab ini dibuka
  /// lagi) sambil diam-diam refresh di belakang layar. Pull-to-refresh dan
  /// aksi join selalu memaksa fetch baru (useCache: false).
  void _loadSpaces({bool useCache = false}) {
    // Cache hanya berisi daftar penuh, jadi tidak boleh dipakai saat sedang
    // mencari — kalau dipakai, hasil pencarian akan tertimpa daftar lengkap.
    final cached = _searchQuery.isEmpty ? ApiService.cachedSpaces : null;
    if (useCache && cached != null) {
      setState(() {
        _allFetchedSpaces = cached;
        _spacesFuture = Future.value(cached);
      });
      ApiService.fetchSpaces()
          .then((spaces) {
            if (mounted) {
              setState(() {
                _allFetchedSpaces = spaces;
                _spacesFuture = Future.value(spaces);
              });
            }
          })
          .catchError((_) {});
      return;
    }

    setState(() {
      _spacesFuture = ApiService.fetchSpaces(search: _searchQuery).then((
        spaces,
      ) {
        _allFetchedSpaces = spaces;
        return spaces;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        children: [
          // Background - Soft Blue Solid
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFDFEFFF), // Biru cerah agak keputihan
                    Color(0xFFECF0FD), // Transisi lembut
                    Color(0xFFF3EBFC), // Gradasi ungu tipis di ujung
                  ],
                ),
              ),
            ),
          ),

          // Data List
          Positioned.fill(
            top: 70, // Beri jarak untuk header
            child: Column(
              children: [
                _buildSearchAndSortBar(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      _loadSpaces();
                      await _spacesFuture;
                    },
                    child: FutureBuilder<List<SpaceModel>>(
                      future: _spacesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF6366F1),
                            ),
                          );
                        } else if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return const Center(child: Text('Belum ada space.'));
                        }

                        final query = _searchQuery.toLowerCase();
                        var filteredSpaces = _allFetchedSpaces.where((space) {
                          // Filter tab Joined/All: murni pilihan lokal.
                          if (!_showAllSpaces && !space.isJoined) return false;

                          // Penyaring cadangan. Kata kunci SUDAH dikirim ke
                          // server lewat ?search=, tapi belum terbukti apakah
                          // endpoint /spaces benar-benar menghormatinya —
                          // endpoint ini bahkan tidak dipaginate. Kalau server
                          // mengabaikannya, tanpa penyaring ini pencarian akan
                          // menampilkan SELURUH space apa pun yang diketik,
                          // dan terlihat seperti rusak.
                          if (query.isEmpty) return true;
                          return space.title.toLowerCase().contains(query) ||
                              space.description.toLowerCase().contains(query);
                        }).toList();

                        // Local Sorting
                        if (_sortBy == 'Alphabetical') {
                          filteredSpaces.sort(
                            (a, b) => a.title.compareTo(b.title),
                          );
                        } else if (_sortBy == 'Members') {
                          filteredSpaces.sort(
                            (a, b) => b.membersCount.compareTo(a.membersCount),
                          );
                        }

                        if (filteredSpaces.isEmpty) {
                          return Center(
                            child: Text(
                              _searchQuery.isEmpty
                                  ? 'Tidak ada space di kategori ini.'
                                  : 'Tidak ada space yang cocok dengan "$_searchQuery".',
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            bottom: 80,
                            top: 8,
                          ),
                          itemCount: filteredSpaces.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            return _buildSpaceCard(filteredSpaces[index]);
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Header diletakkan di atas agar shadow tidak tertutup list
          Align(alignment: Alignment.topCenter, child: _buildSpacesHeader()),
        ],
      ),
    );
  }

  Widget _buildSearchAndSortBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.9),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF64A0DC).withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          onChanged: _onSearchChanged,
          style: const TextStyle(color: Color(0xFF1E293B), fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Search Space...',
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF94A3B8),
              size: 22,
            ),
            filled: true,
            fillColor: Colors.transparent,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 0,
              horizontal: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverFallback(SpaceModel space) {
    if (space.emoji.isNotEmpty) {
      return Container(
        color: const Color(0xFF6366F1).withValues(alpha: 0.08),
        child: Center(
          child: Text(space.emoji, style: const TextStyle(fontSize: 44)),
        ),
      );
    }
    return Container(
      color: const Color(0xFF6366F1).withValues(alpha: 0.08),
      child: const Center(
        child: Icon(Icons.image_outlined, color: Color(0xFFA5B4FC), size: 36),
      ),
    );
  }

  /// Isian kotak logo 48x48 saat space tidak punya logo.
  Widget _buildLogoFallback(SpaceModel space) {
    if (space.emoji.isNotEmpty) {
      return Center(
        child: Text(space.emoji, style: const TextStyle(fontSize: 22)),
      );
    }
    return const Center(
      child: Icon(Icons.group_rounded, color: Color(0xFF818CF8), size: 22),
    );
  }

  Widget _buildSpaceCard(SpaceModel space) {
    // Gradient border wrapper — teknik terbaik untuk border "mengkilap kayak kaca"
    // Container luar: background = gradient (dari putih cerah atas ke setengah transparan bawah)
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.0),
        boxShadow: [
          // Soft drop shadow
          BoxShadow(
            color: const Color(0xFF64A0DC).withValues(alpha: 0.15),
            blurRadius: 24,
            spreadRadius: -2,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.45), // Milky glass
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 1.5,
              ), // Glossy white border
              // Inner highlight gradient (mengkilap di bagian atas)
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.60),
                  Colors.white.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.25, 1.0],
              ),
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                          ),
                          child: SizedBox(
                            height: 140,
                            width: double.infinity,
                            child: space.coverPhotoUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: space.coverPhotoUrl,
                                    httpHeaders: AuthService.imageAuthHeaders,
                                    height: 140,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) =>
                                        _buildCoverFallback(space),
                                  )
                                : _buildCoverFallback(space),
                          ),
                        ),
                        if (space.isJoined)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF34D399),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Member',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFE0E7FF,
                                  ), // Lavender/indigo
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.0,
                                  ), // Glossy border
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF64A0DC,
                                      ).withValues(alpha: 0.20),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipOval(
                                      child: space.logoUrl.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: space.logoUrl,
                                              httpHeaders:
                                                  AuthService.imageAuthHeaders,
                                              width: 48,
                                              height: 48,
                                              fit: BoxFit.cover,
                                              errorWidget:
                                                  (context, url, error) =>
                                                      _buildLogoFallback(space),
                                            )
                                          : _buildLogoFallback(space),
                                    ),
                                    // Overlay kaca mengkilap (glossy app icon effect)
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.white.withValues(
                                              alpha: 0.9,
                                            ), // Sangat terang di pojok atas kiri
                                            Colors.white.withValues(alpha: 0.2),
                                            Colors.transparent,
                                          ],
                                          stops: const [0.0, 0.4, 1.0],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      space.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.public,
                                          size: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          space.privacy,
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(
                                          Icons.group_rounded,
                                          size: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          ' Members',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            space.description.replaceAll(
                              RegExp(r'<[^>]*>'),
                              '',
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Tombol View/Join
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF64A0DC,
                                  ).withValues(alpha: 0.15), // Soft drop shadow
                                  blurRadius: 12,
                                  spreadRadius: -1,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 12,
                                  sigmaY: 12,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      width: 1.5,
                                    ), // Glossy border
                                    // Highlight putih mengkilap di atas tombol
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white.withValues(
                                          alpha: 0.85,
                                        ), // Sangat terang di atas
                                        Colors.white.withValues(alpha: 0.20),
                                        Colors.white.withValues(alpha: 0.0),
                                      ],
                                      stops: const [0.0, 0.35, 1.0],
                                    ),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(24),
                                      onTap: () async {
                                        if (space.isJoined) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  SpaceWebViewScreen(
                                                    spaceSlug: space.slug,
                                                    title: space.title,
                                                  ),
                                            ),
                                          );
                                        } else {
                                          bool success =
                                              await ApiService.joinSpace(
                                                space.slug,
                                              );
                                          if (success) {
                                            _loadSpaces();
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Berhasil bergabung ke Space!',
                                                  ),
                                                ),
                                              );
                                            }
                                          } else {
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Gagal bergabung ke Space.',
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        }
                                      },
                                      child: Container(
                                        height: 46,
                                        alignment: Alignment.center,
                                        child: Text(
                                          space.isJoined
                                              ? 'View Space'
                                              : 'Join Space',
                                          style: const TextStyle(
                                            color: Color(0xFF0F172A),
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Shine overlay — simulasi pantulan cahaya di permukaan kaca
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 80, // Lebih tinggi sedikit
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24.0),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(
                            alpha: 0.35,
                          ), // Jauh lebih mengkilat
                          Colors.white.withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpacesHeader() {
    return Container(
      width: double.infinity,
      height: 64,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
      ), // Kurangi padding agar muat
      color: Colors.transparent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Spaces',
            style: TextStyle(
              fontSize: 22, // Kurangi ukuran font judul
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 6),
          // Semua elemen kanan dalam satu Expanded
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Pill filter group
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.30),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.50),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildFilterChip(
                          'All Spaces',
                          selected: _showAllSpaces,
                        ),
                        const SizedBox(width: 1),
                        _buildFilterChip(
                          'My Spaces',
                          selected: !_showAllSpaces,
                        ),
                      ],
                    ),
                  ),
                  // Tombol admin
                  AdminOnly(
                    builder: (context) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: _openNewSpace,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.40),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.60),
                                width: 1.2,
                              ),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              color: Colors.grey.shade700,
                              size: 16,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Menu',
                          icon: Icon(
                            Icons.more_vert_rounded,
                            color: Colors.grey.shade700,
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          onSelected: (value) {
                            if (value == 'space_groups') _openSpaceGroups();
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'space_groups',
                              child: Text('View Space Groups'),
                            ),
                          ],
                        ),
                      ],
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

  /// Buka halaman spaces di portal web, lalu otomatis klik tombol "New
  /// Space" asli milik web (lewat `autoClickText`) — persis pola yang sama
  /// dipakai navigasi sidebar admin di `AdminPortalDrawer`, hanya saja
  /// tombol ini letaknya di toolbar halaman, bukan di sidebar. Modal "Choose
  /// a Space Type" → form pembuatan yang muncul sesudahnya adalah modal ASLI
  /// dari web, bukan tebakan/form buatan sendiri, jadi apa pun yang dipilih
  /// user di sana benar-benar tersimpan di server.
  ///
  /// Dipakai [AuthenticatedWebViewScreen], BUKAN [SpaceWebViewScreen] —
  /// percobaan pertama pakai SpaceWebViewScreen ternyata salah: CSS
  /// dasarnya didesain untuk halaman DETAIL satu space (menyembunyikan
  /// `.spaces`/`.space_contents` sebagai "sidebar daftar space"), padahal di
  /// halaman LISTING seperti ini, `.spaces`/`.space_contents` kemungkinan
  /// besar justru KONTEN UTAMANYA sendiri — jadi seluruh halaman ikut
  /// tersembunyi, bukan cuma sidebar. `AuthenticatedWebViewScreen` tidak
  /// menyentuh class itu sama sekali, jadi jauh lebih aman untuk halaman ini.
  void _openNewSpace() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AuthenticatedWebViewScreen(
          title: 'New Space',
          url: 'https://titc.or.id/portal/discover/spaces',
          autoClickText: 'New Space',
          extraCss: _newSpaceExtraCss,
        ),
      ),
    );
  }

  /// Drawer Element Plus (el-drawer) dari kanan muncul saat "New Space" diklik.
  /// CSS memaksa drawer memenuhi lebar layar — kalau tidak, di HP hanya
  /// tampil 30-50% dan elemen form terpotong.
  static const String _newSpaceExtraCss = '''
    /* Overlay tidak perlu transparan untuk drawer — biarkan default gelap */
    .el-overlay {
      position: fixed !important;
      inset: 0 !important;
      z-index: 2000 !important;
    }
    /* Drawer fullscreen: paksa 100% lebar agar pas di layar HP */
    .el-drawer {
      width: 100% !important;
      max-width: 100% !important;
      height: 100vh !important;
      border-radius: 0 !important;
      box-shadow: none !important;
      display: flex !important;
      flex-direction: column !important;
    }
    .el-drawer__header {
      flex: none !important;
      padding: 12px 16px !important;
      border-bottom: 1px solid #eee !important;
    }
    .el-drawer__body {
      flex: 1 1 auto !important;
      overflow-y: auto !important;
      -webkit-overflow-scrolling: touch !important;
      padding: 16px !important;
    }
    .el-drawer__footer {
      flex: none !important;
      padding: 12px 16px !important;
      border-top: 1px solid #eee !important;
    }
    /* Kembalikan ukuran button ke normal karena CSS base AuthenticatedWebViewScreen
       memaksa semua button jadi full-width yang merusak tombol di drawer */
    button {
      width: auto !important;
      display: inline-flex !important;
      margin-top: 0 !important;
    }
  ''';

  /// Buka "Space Groups" di portal admin — item sidebar yang sudah ada &
  /// terbukti jalan di [AdminPortalDrawer], sekarang juga bisa diakses
  /// langsung dari layar Spaces lewat menu "⋮".
  void _openSpaceGroups() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SpaceWebViewScreen(
          title: 'Space Groups',
          overrideUrl: 'https://titc.or.id/portal/admin/',
          useAdminDrawer: true,
          initialAdminLabel: 'Space Groups',
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, {required bool selected}) {
    return GestureDetector(
      onTap: () => setState(() => _showAllSpaces = label == 'All Spaces'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 4,
        ), // Diperkecil agar muat
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFD6EDFD) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: selected ? Border.all(color: Colors.white, width: 1.5) : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF64A0DC).withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            fontWeight: FontWeight.w600,
            fontSize: 12, // Font lebih kecil supaya hemat tempat
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}
