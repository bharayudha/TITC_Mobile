import 'package:flutter/material.dart';

import 'package:magang_titc/constants/app_colors.dart';
import 'package:magang_titc/constants/fcom_post_dialog_css.dart';
import 'package:magang_titc/services/notifications_service.dart';

import 'package:magang_titc/models/notification_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:magang_titc/services/auth_service.dart';
import 'package:magang_titc/screens/customer/spaces/space_webview_screen.dart';
import 'package:magang_titc/screens/shared/authenticated_webview_screen.dart';

const List<String> _notificationTabs = [
  'Recent',
  'Unread',
  'Mentions',
  'Following',
];

/// Menampilkan popup notifikasi yang menempel di bawah app bar, sejajar
/// dengan ikon lonceng di kanan atas.
Future<void> showNotificationsPopup(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Tutup notifikasi',
    barrierColor: Colors.black12,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) {
      return const NotificationsPopup();
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          // Muncul dari arah app bar, bukan mengambang begitu saja.
          position: Tween<Offset>(
            begin: const Offset(0, -0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Panel daftar notifikasi.
class NotificationsPopup extends StatefulWidget {
  const NotificationsPopup({super.key});

  @override
  State<NotificationsPopup> createState() => _NotificationsPopupState();
}

class _NotificationsPopupState extends State<NotificationsPopup> {
  int _selectedTab = 0;
  bool _isLoading = true;
  List<NotificationModel> _notifications = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final tabStr = _notificationTabs[_selectedTab].toLowerCase();
      final data = await NotificationsService.fetchNotifications(type: tabStr);
      if (mounted) {
        setState(() {
          _notifications = data;
        });
      }
    } catch (e) {
      print('Failed to load notifications: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dibatasi lebarnya agar tetap rapi di layar lebar, tetapi menyusut
    // mengikuti layar sempit.
    final width = MediaQuery.sizeOf(context).width;
    final panelWidth = width - 24 < 360 ? width - 24 : 360.0;

    return Align(
      alignment: Alignment.topRight,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: kToolbarHeight - 8, right: 8),
          child: Material(
            color: Colors.white,
            elevation: 8,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: panelWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  _buildTabs(),
                  _buildBody(),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Recent Notifications',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          _buildOutlinedAction(
            label: 'Mark all as read',
            onTap: () async {
              final error = await NotificationsService.markAllAsRead();
              if (mounted) {
                if (error == null) {
                  setState(() {
                    for (var n in _notifications) {
                      n.isRead = true;
                    }
                  });
                  _fetchNotifications();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $error')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.divider,
            width: kDividerThickness,
          ),
        ),
      ),
      // Digulir mendatar supaya semua tab tetap terjangkau di layar sempit.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: List.generate(_notificationTabs.length, (index) {
            final selected = index == _selectedTab;
            return GestureDetector(
              onTap: () {
                if (_selectedTab == index) return;
                setState(() => _selectedTab = index);
                _fetchNotifications();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  _notificationTabs[index],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? AppColors.primary : Colors.black87,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        child: Text(
          'Error: $_error',
          style: const TextStyle(fontSize: 14, color: Colors.red),
        ),
      );
    }

    if (_notifications.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 20, 16, 20),
        child: Text(
          'No notifications found',
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 350),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _notifications.length,
        separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.divider),
        itemBuilder: (context, index) {
          final notif = _notifications[index];
          return _buildNotificationItem(notif);
        },
      ),
    );
  }

  Widget _buildNotificationItem(NotificationModel notif) {
    return InkWell(
      onTap: () {
        String? targetUrl = notif.url;

        // Pendekatan baru: Percayakan pada URL bawaan dari FCOM API (karena FCOM sudah membuat link yang tepat).
        // Kadang FCOM mengembalikan URL relatif (dimulai dengan '/'), jadi kita pastikan jadi absolut.
        if (targetUrl != null && targetUrl.isNotEmpty) {
           if (targetUrl.startsWith('/')) {
              targetUrl = 'https://titc.or.id$targetUrl';
           }
        } else if (notif.route != null) {
           // Jika FCOM tidak memberikan URL, kita rakit sendiri secara dinamis berdasarkan parameter yang ada.
           final params = notif.route!['params'] as Map<String, dynamic>? ?? {};
           
           final space = params['space'] ?? params['group'];
           final slug = params['slug'] ?? params['post'] ?? params['post_slug'] ?? params['id'] ?? params['feed_id'] ?? params['feed'];
           final user = params['user'] ?? params['username'];

           if (space != null && slug != null) {
             targetUrl = 'https://titc.or.id/portal/space/$space/post/$slug';
           } else if (slug != null) {
             targetUrl = 'https://titc.or.id/portal/post/$slug';
           } else if (space != null) {
             targetUrl = 'https://titc.or.id/portal/space/$space';
           } else if (user != null) {
             targetUrl = 'https://titc.or.id/portal/u/$user';
           }
        }

        // Jika semua gagal, baru lempar ke halaman depan portal.
        targetUrl ??= 'https://titc.or.id/portal/';

        // Decrement local badge counter if it was unread
        if (!notif.isRead) {
          setState(() {
            notif.isRead = true;
          });
          if (NotificationsService.unreadCountNotifier.value > 0) {
            NotificationsService.unreadCountNotifier.value -= 1;
          }
          NotificationsService.markAsRead(notif.id);
        }

        Widget nextScreen;
        if (targetUrl.contains('/portal/u/')) {
          nextScreen = AuthenticatedWebViewScreen(
            url: targetUrl,
            title: 'Member Profile',
          );
        } else {
          // Post dibuka FCOM sebagai dialog overlay, jadi butuh CSS yang
          // sama persis dengan yang dipakai ikon komentar di Home —
          // sebelumnya di sini ada salinan terpotong (kehilangan aturan
          // footer, tombol, dan `.fcom_dot_menu` per komentar), itulah
          // kenapa post dari notifikasi tampil beda dari yang dibuka lewat
          // Home. Sekarang keduanya menunjuk ke satu konstanta yang sama.
          //
          // Diterapkan TANPA syarat URL mengandung '/post/': notifikasi
          // datang dalam banyak bentuk URL, dan pengecekan itu membuat
          // sebagian post tidak dapat CSS sama sekali. Aman karena semua
          // aturannya hanya cocok kalau `.el-dialog` memang ada.
          nextScreen = SpaceWebViewScreen(
            overrideUrl: targetUrl,
            title: 'Notification',
            extraCss: kFcomPostDialogCss,
          );
        }

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => nextScreen,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        color: notif.isRead ? Colors.transparent : AppColors.primary.withOpacity(0.05),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notif.actor != null)
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: notif.actor!.avatarUrl.isNotEmpty
                    ? CachedNetworkImageProvider(
                        notif.actor!.avatarUrl,
                        headers: AuthService.imageAuthHeaders,
                      )
                    : null,
                child: notif.actor!.avatarUrl.isEmpty
                    ? Text(
                        notif.actor!.displayName.isNotEmpty ? notif.actor!.displayName[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      )
                    : null,
              )
            else
              const CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.divider,
                child: Icon(Icons.notifications, size: 20, color: Colors.black54),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notif.content.replaceAll(RegExp(r'<[^>]*>'), ''), // Strip HTML
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      fontWeight: notif.isRead ? FontWeight.normal : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.dateNotified,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: _buildOutlinedAction(
          label: 'View All',
          // TODO: buka halaman daftar notifikasi lengkap.
          onTap: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  Widget _buildOutlinedAction({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.inputBorder),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.black87),
        ),
      ),
    );
  }
}
