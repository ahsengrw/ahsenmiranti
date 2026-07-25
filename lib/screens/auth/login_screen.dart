import 'package:flutter/material.dart';
import 'register_screen.dart';
import '../customer/customer_dashboard.dart';
import '../driver/driver_dashboard.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final String userRole; // 'customer' or 'driver'

  const LoginScreen({super.key, required this.userRole});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(text: 'russell@example.com');
  final _passwordController = TextEditingController(text: 'password123');
  bool _isLoading = false;

  bool get isDriver => widget.userRole == 'driver';
  Color get primaryColor => isDriver ? const Color(0xFF4A2C2A) : const Color(0xFF4A2C2A); // Matching logo
  Color get bgColor => isDriver ? const Color(0xFF111827) : Colors.white;
  Color get textColor => isDriver ? Colors.white : const Color(0xFF4A2C2A);
  Color get subtitleColor => isDriver ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
  Color get inputBgColor => isDriver ? const Color(0xFF1F2937) : const Color(0xFFF9FAFB);
  Color get inputBorderColor => isDriver ? const Color(0xFF374151) : const Color(0xFFE2E8F0);

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('Please enter email and password.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await AuthService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      if (user.role != widget.userRole && user.role != 'admin') {
        _showError('Invalid portal for this account type.');
        await AuthService.logout();
        return;
      }

      if (user.role == 'driver') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const DriverDashboard()),
              (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const CustomerDashboard()),
              (route) => false,
        );
      }
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300)), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isDriver) ...[
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_shipping, color: Colors.white, size: 24),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                isDriver ? 'Driver Portal' : 'Sign In',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w400, color: textColor),
              ),
              const SizedBox(height: 8),
              Text(
                isDriver ? 'Authorized personnel only.' : 'Welcome back to ProBeading.',
                style: TextStyle(color: subtitleColor, fontSize: 13, fontWeight: FontWeight.w300),
              ),
              const SizedBox(height: 32),

              Text(
                'EMAIL ADDRESS',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: subtitleColor, letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w300),
                decoration: InputDecoration(
                  hintText: 'Enter your email',
                  hintStyle: TextStyle(color: subtitleColor, fontSize: 13, fontWeight: FontWeight.w300),
                  filled: true,
                  fillColor: inputBgColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: inputBorderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: inputBorderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'PASSWORD',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: subtitleColor, letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w300),
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  hintStyle: TextStyle(color: subtitleColor, fontSize: 13, fontWeight: FontWeight.w300),
                  filled: true,
                  fillColor: inputBgColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: inputBorderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: inputBorderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor),
                  ),
                ),
              ),

              if (!isDriver) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: Text('Forgot Password?', style: TextStyle(color: primaryColor, fontWeight: FontWeight.w400, fontSize: 12)),
                  ),
                ),
              ] else const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(isDriver ? 'Access Dashboard' : 'Sign In', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
                ),
              ),

              if (!isDriver) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account? ", style: TextStyle(color: subtitleColor, fontSize: 12, fontWeight: FontWeight.w300)),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      child: Text('Sign Up', style: TextStyle(color: primaryColor, fontWeight: FontWeight.w500, fontSize: 12)),
                    ),
                  ],
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
