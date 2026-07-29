import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'screens/auth/splash_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Start the app immediately to prevent black screen hangs
  runApp(const DeliveryApp());

  // Initialize services in background
  _initServices();
}

Future<void> _initServices() async {
  try {
    // Set Stripe identity
    Stripe.merchantIdentifier = 'merchant.com.meranti.beading';
    await NotificationService.init();
  } catch (e) {
    debugPrint("Service init failed: $e");
  }
}

class DeliveryApp extends StatelessWidget {
  const DeliveryApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beading Delivery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF4A2C2A),
        scaffoldBackgroundColor: const Color(0xFFFDFCF0),
        fontFamily: 'Inter',
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w300),
          bodyMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w300),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF4A2C2A),
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Colors.white),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A2C2A),
          primary: const Color(0xFF4A2C2A),
          secondary: const Color(0xFFB91C1C),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4A2C2A),
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
