import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/product.dart';
import '../../services/api_service.dart';
import '../../core/constants.dart';
import 'customer_dashboard.dart';

class ConfirmationScreen extends StatefulWidget {
  final Product product;
  final int quantity;
  final String phone;
  final String notes;
  final LatLng location;
  final String paymentMethod;
  final bool isExpress;
  final String? codNote;

  const ConfirmationScreen({
    super.key,
    required this.product,
    required this.quantity,
    required this.phone,
    required this.notes,
    required this.location,
    required this.paymentMethod,
    this.isExpress = false,
    this.codNote,
  });

  @override
  State<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen> with SingleTickerProviderStateMixin {
  bool _isProcessing = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  double _expressFee = 0.0;
  bool _isOutsideAMA = false;
  Map<String, dynamic> _settings = {};
  double _stripeSurcharge = 0.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _scaleAnimation = CurvedAnimation(parent: _animationController, curve: Curves.elasticOut);
    _checkLocationAndFetchSettings();
  }

  Future<void> _checkLocationAndFetchSettings() async {
    if (widget.location.latitude > -34.5 || widget.location.latitude < -35.4 ||
        widget.location.longitude < 138.4 || widget.location.longitude > 138.8) {
      setState(() => _isOutsideAMA = true);
    }

    try {
      final response = await ApiService.get('settings');
      if (response['success'] == true) {
        setState(() {
          _settings = response['data'];
          if (widget.isExpress) {
            _expressFee = double.parse(_settings['express_delivery_fee'].toString());
          }
          
          if (widget.paymentMethod == 'stripe') {
            final double subtotal = widget.product.price * widget.quantity;
            final double outsideFee = _isOutsideAMA ? 50.0 : 0.0;
            final double currentTotal = subtotal + _expressFee + outsideFee;
            
            final double perc = double.parse(_settings['stripe_surcharge_percent'] ?? '0');
            final double fixed = double.parse(_settings['stripe_surcharge_fixed'] ?? '0');
            
            _stripeSurcharge = (currentTotal * (perc / 100)) + fixed;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching settings: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _submitOrder() async {
    if (widget.paymentMethod == 'stripe') {
      await _processStripePayment();
      return;
    }
    
    setState(() => _isProcessing = true);
    final prefs = await SharedPreferences.getInstance();
    final userData = jsonDecode(prefs.getString(AppConstants.keyUserData) ?? '{}');

    try {
      final response = await ApiService.post('orders', {
        'customer_id': userData['id'],
        'payment_method': widget.paymentMethod,
        'delivery_lat': widget.location.latitude,
        'delivery_lng': widget.location.longitude,
        'is_express': widget.isExpress ? 1 : 0,
        'outside_ama': _isOutsideAMA ? 1 : 0,
        'cod_note': widget.codNote,
        'items': [
          {'product_id': widget.product.id, 'quantity': widget.quantity}
        ]
      });

      if (response['success'] == true) {
        _showSuccessAnimation();
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300))));
    }
  }

  Future<void> _processStripePayment() async {
    setState(() => _isProcessing = true);
    final prefs = await SharedPreferences.getInstance();
    final userData = jsonDecode(prefs.getString(AppConstants.keyUserData) ?? '{}');
    
    final double subtotal = widget.product.price * widget.quantity;
    final double outsideFee = _isOutsideAMA ? 50.0 : 0.0;
    final double baseAmount = subtotal + _expressFee + outsideFee;

    try {
      // 1. Create Payment Intent
      final response = await ApiService.post('payment', {
        'customer_id': userData['id'],
        'amount': baseAmount,
      });

      if (response['success'] != true) throw response['message'];

      final data = response['data'];
      final clientSecret = data['client_secret'];
      final publishableKey = data['publishable_key'];

      // 2. Initialize Stripe
      Stripe.publishableKey = publishableKey;
      await Stripe.instance.applySettings();

      // 3. Present Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Meranti Beading',
          applePay: const PaymentSheetApplePay(merchantCountryCode: 'AU'),
          googlePay: const PaymentSheetGooglePay(merchantCountryCode: 'AU', testEnv: true),
          style: ThemeMode.light,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(primary: Color(0xFF4A2C2A)),
          ),
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      // 4. If payment successful, place order
      final orderResponse = await ApiService.post('orders', {
        'customer_id': userData['id'],
        'payment_method': 'stripe',
        'delivery_lat': widget.location.latitude,
        'delivery_lng': widget.location.longitude,
        'is_express': widget.isExpress ? 1 : 0,
        'outside_ama': _isOutsideAMA ? 1 : 0,
        'cod_note': widget.codNote,
        'items': [
          {'product_id': widget.product.id, 'quantity': widget.quantity}
        ]
      });

      if (orderResponse['success'] == true) {
        _showSuccessAnimation();
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (e is StripeException) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment ${e.error.localizedMessage}', style: const TextStyle(fontSize: 12))));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment Error: $e', style: const TextStyle(fontSize: 12))));
      }
    }
  }

  void _showSuccessAnimation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 60),
                const SizedBox(height: 20),
                Text('Order Confirmed!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400, color: Theme.of(context).primaryColor)),
              ],
            ),
          ),
        ),
      ),
    );
    _animationController.forward();

    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const CustomerDashboard(initialIndex: 1)),
            (route) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final double subtotal = widget.product.price * widget.quantity;
    final double outsideFee = _isOutsideAMA ? 50.0 : 0.0;
    final double total = subtotal + _expressFee + outsideFee + _stripeSurcharge;

    return Scaffold(
      backgroundColor: const Color(0xFFFDFCF0),
      appBar: AppBar(
        title: const Text('Order Summary'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${widget.quantity}x ${widget.product.name}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
                      Text('\$${subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
                    ],
                  ),
                  if (widget.isExpress)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Express Delivery Fee', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w300)),
                          Text('\$${_expressFee.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w300)),
                        ],
                      ),
                    ),
                  if (_isOutsideAMA)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Outside Metro Area Fee', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w300)),
                          const Text('\$50.00', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w300)),
                        ],
                      ),
                    ),
                  if (widget.paymentMethod == 'stripe')
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Online Payment Surcharge', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w300)),
                          Text('\$${_stripeSurcharge.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w300)),
                        ],
                      ),
                    ),
                  const Divider(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      Text('\$${total.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Theme.of(context).primaryColor)),
                    ],
                  ),
                  const Divider(height: 30),
                  _buildSummaryRow('Payment', widget.paymentMethod == 'stripe' ? 'Online Payment' : 'Cash on Delivery'),
                  const SizedBox(height: 10),
                  _buildSummaryRow('Contact', widget.phone),
                  const SizedBox(height: 10),
                  _buildSummaryRow('Location', '${widget.location.latitude.toStringAsFixed(4)}, ${widget.location.longitude.toStringAsFixed(4)}'),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _submitOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Confirm & Place Order', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w300))),
        Expanded(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w400, fontSize: 12))),
      ],
    );
  }
}
