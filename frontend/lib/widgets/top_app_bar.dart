import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../constants/app_colors.dart';
import 'notifications_popup.dart';
import 'profile_menu.dart';
import 'search_overlay.dart';

class TitcAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TitcAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      // Drop shadow lembut, bukan garis datar.
      elevation: 3,
      scrolledUnderElevation: 3,
      shadowColor: kShadowColor,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const PhosphorIcon(
          PhosphorIconsRegular.list,
          color: Colors.black87,
        ),
        onPressed: () => Scaffold.of(context).openDrawer(),
      ),
      title: RichText(
        text: const TextSpan(
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          children: [
            TextSpan(text: 'TITC ', style: TextStyle(color: AppColors.primary)),
            TextSpan(text: 'Indonesia', style: TextStyle(color: Colors.black54)),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const PhosphorIcon(
            PhosphorIconsRegular.magnifyingGlass,
            color: Colors.black87,
          ),
          onPressed: () => showSearchOverlay(context),
        ),
        IconButton(
          icon: const PhosphorIcon(
            PhosphorIconsRegular.bell,
            color: Colors.black87,
          ),
          onPressed: () => showNotificationsPopup(context),
        ),
        const ProfileMenuButton(),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
