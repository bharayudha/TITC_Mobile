import 'package:flutter/material.dart';
import 'package:magang_titc/services/api_service.dart';
import 'package:magang_titc/services/auth_service.dart';
import 'package:magang_titc/constants/app_colors.dart';

class ProfileEditScreen extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String email;
  final String bio;
  final String headline;
  final Map<String, String> socialLinks;

  // Field pass-through — tidak diedit lewat form ini, tapi harus ikut
  // dikirim ulang persis seperti bentuk request web asli (lihat komentar
  // di ApiService.updateFcomProfile), kalau tidak server membalas 200
  // tanpa benar-benar menyimpan apa pun.
  final String username;
  final int userId;
  final String status;
  final int isVerified;
  final String isFlagged;
  final List<String> badgeSlugs;
  final Map<String, dynamic> customFields;

  const ProfileEditScreen({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.bio,
    this.headline = '',
    this.socialLinks = const {},
    this.username = '',
    this.userId = 0,
    this.status = 'active',
    this.isVerified = 0,
    this.isFlagged = 'no',
    this.badgeSlugs = const [],
    this.customFields = const {},
  });

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _websiteController;
  late TextEditingController _headlineController;
  late TextEditingController _bioController;

  // Social Links
  late TextEditingController _igController;
  late TextEditingController _ytController;
  late TextEditingController _linkedinController;
  late TextEditingController _fbController;
  late TextEditingController _tiktokController;
  late TextEditingController _telegramController;

  // Passwords
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;

  bool _isLoading = false;
  bool _isChangingPassword = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.firstName);
    _lastNameController = TextEditingController(text: widget.lastName);
    _emailController = TextEditingController(text: widget.email);
    _websiteController = TextEditingController();
    _headlineController = TextEditingController(text: widget.headline);
    _bioController = TextEditingController(text: widget.bio);

    _igController = TextEditingController(text: widget.socialLinks['instagram'] ?? '');
    _ytController = TextEditingController(text: widget.socialLinks['youtube'] ?? '');
    _linkedinController = TextEditingController(text: widget.socialLinks['linkedin'] ?? '');
    _fbController = TextEditingController(text: widget.socialLinks['facebook'] ?? '');
    _tiktokController = TextEditingController(text: widget.socialLinks['tiktok'] ?? '');
    _telegramController = TextEditingController(text: widget.socialLinks['telegram'] ?? '');

    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _headlineController.dispose();
    _bioController.dispose();
    _igController.dispose();
    _ytController.dispose();
    _linkedinController.dispose();
    _fbController.dispose();
    _tiktokController.dispose();
    _telegramController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);

    // Save basic WP profile data
    final wpSuccess = await ApiService.updateProfile(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      bio: _bioController.text.trim(),
      email: _emailController.text.trim(),
      website: _websiteController.text.trim(),
      meta: {
        'headline': _headlineController.text.trim(),
        'instagram': _igController.text.trim(),
        'youtube': _ytController.text.trim(),
        'linkedin': _linkedinController.text.trim(),
        'facebook': _fbController.text.trim(),
        'tiktok': _tiktokController.text.trim(),
        'telegram': _telegramController.text.trim(),
      },
    );

    // Save FCOM profile data — kirim hanya field yang dikenali, tanpa
    // username/user_id/custom_fields yang bisa menyebabkan silent reject.
    bool fcomSuccess = true;
    if (AuthService.userSlug != null) {
      // Hanya kirim social link yang terisi
      final rawLinks = <String, String>{
        'instagram': _igController.text.trim(),
        'youtube': _ytController.text.trim(),
        'linkedin': _linkedinController.text.trim(),
        'facebook': _fbController.text.trim(),
        'tiktok': _tiktokController.text.trim(),
        'telegram': _telegramController.text.trim(),
      };
      final socialLinks = Map<String, String>.fromEntries(
        rawLinks.entries.where((e) => e.value.isNotEmpty),
      );

      // Bentuk ini disalin persis dari cURL DevTools web asli (bukan
      // tebakan) — `headline`/`social_links` memang ada di root `data`,
      // tapi server hanya benar-benar menyimpan kalau field pass-through
      // (username, user_id, status, dst) ikut dikirim juga.
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final fcomData = <String, dynamic>{
        'username': widget.username,
        'display_name': '$firstName $lastName'.trim(),
        'first_name': firstName,
        'last_name': lastName,
        'email': _emailController.text.trim(),
        'website': _websiteController.text.trim(),
        'headline': _headlineController.text.trim(),
        'short_description': _bioController.text.trim(),
        'user_id': widget.userId,
        'is_verified': widget.isVerified,
        'is_flagged': widget.isFlagged,
        'social_links': socialLinks,
        'badge_slugs': widget.badgeSlugs,
        'status': widget.status,
        'custom_fields': widget.customFields,
      };

      fcomSuccess = await ApiService.updateFcomProfile(
        slug: AuthService.userSlug!,
        data: fcomData,
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (wpSuccess && fcomSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
      // Langsung pop — ProfileScreen akan fetch data baru setelah kembali.
      if (mounted) Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update profile. Please try again.')),
      );
    }
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match!')),
      );
      return;
    }
    
    // In WP REST API, changing password is done by passing 'password' to users/me
    // Note: FCOM might have a different flow requiring current password, but standard WP allows it if authenticated.
    setState(() => _isChangingPassword = true);
    final success = await ApiService.updateProfile(
      password: _newPasswordController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isChangingPassword = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully!')),
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to change password.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Account Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // PROFILE SECTION
            _buildSectionContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildTextField('First Name *', _firstNameController)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField('Last Name', _lastNameController)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildTextField('Email', _emailController)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField('Website URL', _websiteController)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField('Headline', _headlineController),
                  const SizedBox(height: 16),
                  _buildTextField('Short Bio', _bioController, maxLines: 4),
                  const SizedBox(height: 24),
                  _buildSocialLinksSection(),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save Changes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // PASSWORD SECTION
            _buildSectionContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Change Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 4),
                  const Text('Update the password you use to log in.', style: TextStyle(fontSize: 13, color: Colors.black54)),
                  const SizedBox(height: 20),
                  _buildTextField('Current Password *', _currentPasswordController, isPassword: true),
                  const SizedBox(height: 16),
                  _buildTextField('New Password *', _newPasswordController, isPassword: true),
                  const SizedBox(height: 16),
                  _buildTextField('Confirm New Password *', _confirmPasswordController, isPassword: true),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isChangingPassword ? null : _changePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isChangingPassword
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Change Password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }

  Widget _buildSocialLinksSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Social Links', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 4),
          const Text('Add your social media profile link.', style: TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildSocialField('Instagram', 'instagram @username', _igController, Icons.camera_alt_outlined)),
              const SizedBox(width: 16),
              Expanded(child: _buildSocialField('YouTube', 'youtube @username', _ytController, Icons.play_circle_outline)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildSocialField('LinkedIn', 'linkedin username', _linkedinController, Icons.link)),
              const SizedBox(width: 16),
              Expanded(child: _buildSocialField('Facebook', 'fb_username', _fbController, Icons.facebook)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildSocialField('TikTok', '@tiktok_username', _tiktokController, Icons.music_note)),
              const SizedBox(width: 16),
              Expanded(child: _buildSocialField('Telegram', 'telegram_username', _telegramController, Icons.telegram)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialField(String label, String hint, TextEditingController controller, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade600),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.primary)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1, bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: isPassword ? 1 : maxLines,
          obscureText: isPassword,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.primary)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }
}
