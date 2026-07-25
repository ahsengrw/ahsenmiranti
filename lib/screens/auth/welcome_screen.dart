import 'package:flutter/material.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _navigateToLogin(BuildContext context, String role) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(userRole: role),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Welcome',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w400,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Please select your account type to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 50),
              ElevatedButton(
                onPressed: () => _navigateToLogin(context, 'customer'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                child: const Text(
                  'I am a Customer',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => _navigateToLogin(context, 'driver'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: primaryColor, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'I am a Delivery Driver',
                  style: TextStyle(
                    fontSize: 14,
                    color: primaryColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
