import 'package:flutter/material.dart';
import 'package:magang_titc/services/api_service.dart';
import 'package:magang_titc/services/auth_service.dart';
import 'package:magang_titc/constants/app_colors.dart';

class ProfileEditScreen extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String email;
  final String bio;

  const ProfileEditScreen({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.bio,
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

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.firstName);
    _lastNameController = TextEditingController(text: widget.lastName);
    _emailController = TextEditingController(text: widget.email);
    _websiteController = TextEditingController();
    _headlineController = TextEditingController();
    _bioController = TextEditingController(text: widget.bio);

    _igController = TextEditingController();
    _ytController = TextEditingController();
    _linkedinController = TextEditingController();
    _fbController = TextEditingController();
    _tiktokController = TextEditingController();
    _telegramController = TextEditingController();

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
    final success = await ApiService.updateProfile(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      bio: _bioController.text.trim(),
      email: _emailController.text.trim(),
      website: _websiteController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
      await AuthService.init();
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
    setState(() => _isLoading = true);
    final success = await ApiService.updateProfile(
      password: _newPasswordController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

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
                    onPressed: _isLoading ? null : _changePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isLoading
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
