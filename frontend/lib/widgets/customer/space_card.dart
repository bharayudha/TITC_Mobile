import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:magang_titc/models/space_model.dart';
import 'package:magang_titc/services/auth_service.dart';
import 'package:magang_titc/screens/customer/spaces/space_webview_screen.dart';

class SpaceCard extends StatelessWidget {
  final SpaceModel space;
  final VoidCallback? onJoinPressed;

  const SpaceCard({
    Key? key,
    required this.space,
    this.onJoinPressed,
  }) : super(key: key);

  Widget _buildCoverFallback() {
    return const Center(
      child: Icon(
        Icons.image_outlined,
        size: 32,
        color: Color(0xFFA5B4FC),
      ),
    );
  }

  Widget _buildLogoFallback() {
    return const Center(
      child: Icon(
        Icons.groups_outlined,
        color: Color(0xFF818CF8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.06),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 24,
                offset: const Offset(0, 8),
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
                              errorWidget: (context, url, error) => _buildCoverFallback(),
                            )
                          : _buildCoverFallback(),
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E).withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                            ),
                            child: const Text(
                              'Member',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
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
                                color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.black.withValues(alpha: 0.06), width: 1.0),
                              ),
                              child: space.logoUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: space.logoUrl,
                                      httpHeaders: AuthService.imageAuthHeaders,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      errorWidget: (context, url, error) => _buildLogoFallback(),
                                    )
                                  : _buildLogoFallback(),
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
                                  color: Colors.black87,
                                  letterSpacing: 0.1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.public, size: 12, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    space.privacy,
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(Icons.group_rounded, size: 12, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${space.membersCount} Members',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                  ),
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
                        color: Colors.grey.shade700,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Action Button
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
                                    foregroundColor: const Color(0xFF6366F1),
                                    side: const BorderSide(color: Color(0xFF6366F1), width: 1.0),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.08),
                                  ),
                                  child: const Text(
                                    'View Space',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: ElevatedButton(
                                  onPressed: onJoinPressed,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6366F1),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Join',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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
}
