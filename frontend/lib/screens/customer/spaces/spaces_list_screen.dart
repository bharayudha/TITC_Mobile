import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:magang_titc/models/space_model.dart';
import 'package:magang_titc/services/api_service.dart';
import 'package:magang_titc/services/auth_service.dart';
import 'package:magang_titc/widgets/shared/admin_only.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
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
      ApiService.fetchSpaces().then((spaces) {
        if (mounted) {
          setState(() {
            _allFetchedSpaces = spaces;
            _spacesFuture = Future.value(spaces);
          });
        }
      }).catchError((_) {});
      return;
    }

    setState(() {
      _spacesFuture = ApiService.fetchSpaces(search: _searchQuery).then((spaces) {
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
          // Background - Vibrant Colorful Mesh
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF4FACFE), // Cerah Biru
                    Color(0xFF00F2FE), // Cerah Cyan
                  ],
                ),
              ),
            ),
          ),
          // Orb 1: Vibrant Pink (Kiri Atas)
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFA709A).withValues(alpha: 0.85),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Orb 2: Vibrant Yellow (Kanan Bawah)
          Positioned(
            bottom: -100,
            right: -150,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFEE140).withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Orb 3: Vibrant Violet (Tengah Kiri)
          Positioned(
            top: 250,
            left: -150,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFE2B0FF).withValues(alpha: 0.85),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Orb 4: Bright Mint (Kanan Atas)
          Positioned(
            top: 50,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF84FAB0).withValues(alpha: 0.85),
                    Colors.transparent,
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
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF6366F1),
                            ),
                          );
                        } else if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
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
                          filteredSpaces.sort((a, b) => a.title.compareTo(b.title));
                        } else if (_sortBy == 'Members') {
                          filteredSpaces.sort((a, b) => b.membersCount.compareTo(a.membersCount));
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
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80, top: 8),
                          itemCount: filteredSpaces.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 16),
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
          Align(
            alignment: Alignment.topCenter,
            child: _buildSpacesHeader(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndSortBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          // Search Field — full glass
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: TextField(
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search Space...',
                  hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: Colors.white.withValues(alpha: 0.9), size: 20),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.25),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3), width: 1.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3), width: 1.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                        color: Colors.white, width: 1.2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Sort By
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Sort by: ',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13)),
              Theme(
                data: Theme.of(context).copyWith(
                  canvasColor: const Color(0xFF4FACFE),
                ),
                child: DropdownButton<String>(
                  value: _sortBy,
                  icon: const Icon(Icons.keyboard_arrow_down,
                      size: 18, color: Colors.white),
                  elevation: 8,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  dropdownColor: const Color(0xFF00F2FE),
                  underline: const SizedBox(),
                  onChanged: (String? value) {
                    if (value != null) setState(() => _sortBy = value);
                  },
                  items: <String>['Alphabetical', 'Members']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                        value: value, child: Text(value));
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Isian saat space tidak punya cover (atau covernya gagal dimuat).
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
        child: Icon(Icons.image_outlined,
            color: Color(0xFFA5B4FC), size: 36),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            // Efek kaca asli dengan gradien sangat transparan
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.45),
                Colors.white.withValues(alpha: 0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3), // Edge highlight tipis
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15), // Separasi bayangan
                blurRadius: 30,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cover image & Tag
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    child: SizedBox(
                      height: 130,
                      width: double.infinity,
                      child: space.coverPhotoUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: space.coverPhotoUrl,
                              httpHeaders: AuthService.imageAuthHeaders,
                              height: 130,
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
                      top: 10,
                      right: 10,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E).withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.5)),
                            ),
                            child: const Text(
                              'Member',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5),
                            ),
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
                        // Logo
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.4), width: 1.0),
                              ),
                              child: space.logoUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: space.logoUrl,
                                      httpHeaders: AuthService.imageAuthHeaders,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      errorWidget: (context, url, error) =>
                                          _buildLogoFallback(space),
                                    )
                                  : _buildLogoFallback(space),
                            ),
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
                                    color: Colors.white,
                                    letterSpacing: 0.1),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.public,
                                      size: 12, color: Colors.white.withValues(alpha: 0.85)),
                                  const SizedBox(width: 4),
                                  Text(space.privacy,
                                      style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.85),
                                          fontSize: 11)),
                                  const SizedBox(width: 12),
                                  Icon(Icons.group_rounded,
                                      size: 12, color: Colors.white.withValues(alpha: 0.85)),
                                  const SizedBox(width: 4),
                                  Text('${space.membersCount} Members',
                                      style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.85),
                                          fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Description
                    Text(
                      space.description.replaceAll(RegExp(r'<[^>]*>'), ''),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    // Action Button — Glassmorphic Buttons
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: space.isJoined
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SpaceWebViewScreen(
                                          spaceSlug: space.slug,
                                          title: space.title,
                                        ),
                                      ),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                        color: Colors.white.withValues(alpha: 0.3), width: 1.0),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.2), // Transparan glass
                                  ),
                                  child: const Text(
                                    'View Space',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: ElevatedButton(
                                  onPressed: () async {
                                    bool success =
                                        await ApiService.joinSpace(space.slug);
                                    if (success) {
                                      _loadSpaces();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text(
                                                    'Berhasil bergabung ke Space!')));
                                      }
                                    } else {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text(
                                                    'Gagal bergabung ke Space.')));
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white.withValues(alpha: 0.35),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 1.0),
                                    ),
                                  ),
                                  child: const Text(
                                    'Join',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold),
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
        ),
      ),
    );
  }

  /// Header Spaces — custom glass, tidak memakai SectionHeader yang shared
  /// agar tab lain (Home/Courses/Members) tidak terpengaruh.
  Widget _buildSpacesHeader() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: double.infinity,
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.4),
                Colors.white.withValues(alpha: 0.1),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1.0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Spaces',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // Teks putih menonjol
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildFilterChip('All Spaces', selected: _showAllSpaces),
                  const SizedBox(width: 6),
                  _buildFilterChip('My Spaces', selected: !_showAllSpaces),
                  AdminOnly(
                    builder: (context) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: _openNewSpace,
                          icon: const Icon(Icons.add_circle_outline_rounded,
                              color: Color(0xFF6366F1)),
                          tooltip: 'New Space',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Menu',
                          icon: const Icon(Icons.more_vert_rounded,
                              color: Color(0xFF6366F1), size: 20),
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
            ],
          ),
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.2),
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: selected ? FontWeight.bold : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
