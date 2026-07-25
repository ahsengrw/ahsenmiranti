import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../auth/welcome_screen.dart';
import '../../core/constants.dart';
import 'address_picker_screen.dart';
import 'policy_view.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({Key? key}) : super(key: key);

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(AppConstants.keyUserData);
    if (userData != null) {
      final user = jsonDecode(userData);
      setState(() {
        _nameController.text = user['name'] ?? '';
        _emailController.text = user['email'] ?? '';
        _phoneController.text = user['phone'] ?? '';
        _addressController.text = user['address'] ?? '';
        _isLoading = false;
      });
    }
  }

  void _handleLogout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: const Color(0xFFFDFCF0),
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF4A2C2A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Center(
              child: Stack(
                children: [
                  const CircleAvatar(
                    radius: 60,
                    backgroundColor: Color(0xFFF1F5F9),
                    child: Icon(Icons.person, size: 60, color: Color(0xFF94A3B8)),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Color(0xFFB91C1C), shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildTextField('Full Name', _nameController, Icons.person_outline),
            const SizedBox(height: 16),
            _buildTextField('Email', _emailController, Icons.email_outlined, enabled: false),
            const SizedBox(height: 16),
            _buildTextField('Phone Number', _phoneController, Icons.phone_outlined),
            const SizedBox(height: 16),

            _buildPolicyTile('Terms & Conditions', AppConstants.termsAndConditions),
            const SizedBox(height: 12),
            _buildPolicyTile('Privacy Policy', AppConstants.privacyPolicy),
            const SizedBox(height: 12),
            _buildPolicyTile('Returns & Refunds Policy', AppConstants.returnPolicy),
            const SizedBox(height: 24),
            
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Delivery Address', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddressPickerScreen()),
                    );
                    if (result == true) {
                      _loadUserData();
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Color(0xFFB91C1C)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _addressController.text.isEmpty ? 'Tap to set address' : _addressController.text,
                            style: const TextStyle(color: Color(0xFF475569)),
                          ),
                        ),
                        const Icon(Icons.edit, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  // In a real app, send updated name/phone to API
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!')));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A2C2A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Save Changes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyTile(String title, String content) {
    return ListTile(
      leading: const Icon(Icons.description_outlined, color: Color(0xFFB91C1C)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569))),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PolicyView(title: title, content: content)),
        );
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      tileColor: Colors.white,
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool enabled = true, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFFB91C1C)),
            filled: !enabled,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
      ],
    );
  }
}
