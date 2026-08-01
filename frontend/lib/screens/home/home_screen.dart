import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../widgets/section_header.dart';

/// Konten tab Home. App bar, drawer, chat FAB, dan bottom nav dipasang oleh
/// [MainShell].
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionHeader(
          title: 'Feed',
          trailing: IconButton(
            icon: const PhosphorIcon(
              PhosphorIconsRegular.dotsThreeVertical,
              color: Colors.black54,
            ),
            onPressed: () {},
          ),
        ),
        const Expanded(child: SizedBox.expand()),
      ],
    );
  }
}
