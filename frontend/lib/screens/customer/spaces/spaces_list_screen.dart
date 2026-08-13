import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:magang_titc/models/space_model.dart';
import 'package:magang_titc/services/api_service.dart';
import 'package:magang_titc/services/auth_service.dart';
import 'package:magang_titc/widgets/shared/section_header.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:magang_titc/screens/customer/spaces/space_webview_screen.dart';

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
          const Positioned.fill(child: ColoredBox(color: Color(0xFFF5F6F8))),
          
          // Data List
          Positioned.fill(
            top: 70, // Beri jarak untuk SectionHeader
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
                          return const Center(child: CircularProgressIndicator());
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
          // Search Field
          TextField(
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search Space...',
              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass, color: Colors.grey.shade500),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF1E5AF5)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Sort By Dropdown
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Sort by: ', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              DropdownButton<String>(
                value: _sortBy,
                icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                elevation: 16,
                style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600),
                underline: const SizedBox(),
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() {
                      _sortBy = value;
                    });
                  }
                },
                items: <String>['Alphabetical', 'Members']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Isian saat space tidak punya cover (atau covernya gagal dimuat).
  /// Emoji space dipakai lebih dulu supaya kartu tetap punya identitas
  /// visual seperti di web, bukan kotak abu-abu kosong.
  Widget _buildCoverFallback(SpaceModel space) {
    if (space.emoji.isNotEmpty) {
      return Center(
        child: Text(space.emoji, style: const TextStyle(fontSize: 44)),
      );
    }
    return Center(
      child: PhosphorIcon(PhosphorIconsRegular.image, color: Colors.grey.shade400),
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
      child: PhosphorIcon(PhosphorIconsRegular.users, color: Colors.grey),
    );
  }

  Widget _buildSpaceCard(SpaceModel space) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cover image & Tag
          Stack(
            children: [
              Container(
                height: 130,
                color: Colors.grey.shade200,
                child: space.coverPhotoUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: space.coverPhotoUrl,
                        httpHeaders: AuthService.imageAuthHeaders,
                        height: 130,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => _buildCoverFallback(space),
                      )
                    : _buildCoverFallback(space),
              ),
              if (space.isJoined)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Member',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
                    Container(
                      width: 48,
                      height: 48,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: space.logoUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: space.logoUrl,
                              httpHeaders: AuthService.imageAuthHeaders,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => _buildLogoFallback(space),
                            )
                          : _buildLogoFallback(space),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            space.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.public, size: 12, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text(space.privacy, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                              const SizedBox(width: 12),
                              PhosphorIcon(PhosphorIconsRegular.users, size: 12, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text('${space.membersCount} Members', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Description
                Text(
                  space.description.replaceAll(RegExp(r'<[^>]*>'), ''),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                // Action Button
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (space.isJoined) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SpaceWebViewScreen(
                              spaceSlug: space.slug,
                              title: space.title,
                            ),
                          ),
                        );
                      } else {
                        // Show loading indicator in button by calling setState in a stateful way, 
                        // but since we are in _buildSpaceCard, we should trigger a rebuild or use a Future.
                        // For simplicity, we just show a snackbar or local loading if we had it.
                        // Better yet, just call API and refresh.
                        bool success = await ApiService.joinSpace(space.slug);
                        if (success) {
                          _loadSpaces(); // Refresh list to get updated isJoined status
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Berhasil bergabung ke Space!')),
                            );
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Gagal bergabung ke Space.')),
                            );
                          }
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: space.isJoined ? Colors.white : const Color(0xFF1E5AF5),
                      foregroundColor: space.isJoined ? const Color(0xFF1E5AF5) : Colors.white,
                      elevation: 0,
                      side: space.isJoined ? const BorderSide(color: Color(0xFF1E5AF5)) : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      space.isJoined ? 'View Space' : 'Join',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpacesHeader() {
    return SectionHeader(
      title: 'Spaces',
      trailing: Row(
        children: [
          _buildFilterChip('All Spaces', selected: _showAllSpaces),
          const SizedBox(width: 8),
          _buildFilterChip('My Spaces', selected: !_showAllSpaces),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, {required bool selected}) {
    return GestureDetector(
      onTap: () => setState(() => _showAllSpaces = label == 'All Spaces'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF1FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF1E5AF5) : Colors.black54,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
