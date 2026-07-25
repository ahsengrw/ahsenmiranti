import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/product.dart';
import '../../services/api_service.dart';
import 'confirmation_screen.dart';
import '../../core/constants.dart';
import 'address_picker_screen.dart';
import 'policy_view.dart';

class CheckoutScreen extends StatefulWidget {
  final Product product;
  const CheckoutScreen({super.key, required this.product});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  final _codDiscountController = TextEditingController();
  final _addressController = TextEditingController();
  int _quantity = 1;
  String _paymentMethod = 'cod';
  bool _isExpress = false;
  bool _agreedToTerms = false;
  Map<String, dynamic> _settings = {};
  LatLng _selectedLocation = const LatLng(-34.9285, 138.6007); // Adelaide

  bool get _isPastExpressCutoff {
    if (_settings['express_cutoff_time'] == null) return false;
    try {
      final now = DateTime.now();
      final parts = _settings['express_cutoff_time'].split(':');
      final cutoffHour = int.parse(parts[0]);
      final cutoffMinute = int.parse(parts[1]);

      final cutoff = DateTime(now.year, now.month, now.day, cutoffHour, cutoffMinute);
      return now.isAfter(cutoff);
    } catch (e) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchSettings();
    _loadUserData();
    _loadSavedPhone();
  }

  Future<void> _loadSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPhone = prefs.getString('saved_phone');
    if (savedPhone != null) {
      setState(() {
        _phoneController.text = savedPhone;
      });
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataStr = prefs.getString(AppConstants.keyUserData);
    if (userDataStr != null) {
      final user = jsonDecode(userDataStr);
      setState(() {
        _addressController.text = user['address'] ?? '';
        if (user['lat'] != null && user['lng'] != null) {
          _selectedLocation = LatLng(
            double.parse(user['lat'].toString()),
            double.parse(user['lng'].toString()),
          );
        }
      });
    }
  }

  Future<void> _fetchSettings() async {
    try {
      final response = await ApiService.get('settings');
      if (response['success'] == true) {
        setState(() => _settings = response['data']);
      }
    } catch (e) {
      debugPrint('Error fetching settings: $e');
    }
  }

  void _proceedToConfirmation() async {
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a contact number.')));
      return;
    }
    if (_addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a delivery address.')));
      return;
    }

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please agree to the Terms & Conditions.')));
      return;
    }

    // Business Hours Check
    final now = DateTime.now();
    final parts = (_settings['delivery_cutoff_time'] ?? '17:00').split(':');
    final cutoffHour = int.parse(parts[0]);

    if (now.hour >= cutoffHour && !_isExpress && !_isPastExpressCutoff) {
      bool proceed = await _showAfterHoursDialog();
      if (!proceed) return;
    }

    if (_isPastExpressCutoff) {
      _isExpress = false;
    }

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_phone', _phoneController.text);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfirmationScreen(
          product: widget.product,
          quantity: _quantity,
          phone: _phoneController.text,
          notes: _notesController.text,
          location: _selectedLocation,
          paymentMethod: _paymentMethod,
          isExpress: _isExpress,
          codNote: _paymentMethod == 'cod' ? _codDiscountController.text : null,
        ),
      ),
    );
  }

  Future<bool> _showAfterHoursDialog() async {
    final standardCutoff = _settings['delivery_cutoff_time'] ?? '5:00 PM';
    final expressCutoff = _settings['express_cutoff_time'] ?? '12:00 PM';

    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('After Hours Delivery', style: TextStyle(fontWeight: FontWeight.w400)),
        content: Text(
          'It is currently past $standardCutoff. Standard deliveries are scheduled for tomorrow. Would you like to switch to Express Delivery for same-day delivery? (Available until $expressCutoff)',
          style: const TextStyle(fontWeight: FontWeight.w300, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Standard (Tomorrow)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w300)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _isExpress = true);
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, elevation: 0),
            child: const Text('Switch to Express', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCF0),
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset('assets/images/beading.png', width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.image, size: 50)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${widget.product.sizeMm}mm ${widget.product.name}', style: const TextStyle(fontWeight: FontWeight.w400, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text('\$${widget.product.price.toStringAsFixed(2)} / bundle', style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w300)),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey[200]!), borderRadius: BorderRadius.circular(6)),
                    child: Row(
                      children: [
                        IconButton(icon: const Icon(Icons.remove, size: 14), onPressed: () => setState(() { if (_quantity > 1) _quantity--; })),
                        Text('$_quantity', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                        IconButton(icon: const Icon(Icons.add, size: 14), onPressed: () => setState(() => _quantity++)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Delivery Address', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                      TextButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AddressPickerScreen()),
                          );
                          if (result == true) {
                            _loadUserData();
                          }
                        },
                        icon: const Icon(Icons.edit, size: 14),
                        label: const Text('Change', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w300)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      _addressController.text.isEmpty ? 'Loading address...' : _addressController.text,
                      style: const TextStyle(color: Color(0xFF64748B), height: 1.4, fontSize: 12, fontWeight: FontWeight.w300),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Contact & Details', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                  const SizedBox(height: 12),
                  _buildSmallTextField(_phoneController, 'Phone Number', TextInputType.phone),
                  const SizedBox(height: 12),
                  _buildSmallTextField(_notesController, 'Delivery Notes (Optional)', TextInputType.text),
                  const SizedBox(height: 24),
                  const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                  const SizedBox(height: 12),
                  _buildPaymentMethodCard(
                    'cod',
                    'Cash on Delivery (COD)',
                    'Pay when you receive items',
                    Icons.payments_outlined,
                  ),
                  if (_settings['stripe_enabled'] == '1') ...[
                    const SizedBox(height: 10),
                    _buildPaymentMethodCard(
                      'stripe',
                      Platform.isIOS ? 'Credit Card or Apple Pay' : 'Credit Card or GPay',
                      'Secure online payment',
                      Icons.credit_card_outlined,
                    ),
                  ],
                  if (_paymentMethod == 'cod') ...[
                    const SizedBox(height: 16),
                    _buildSmallTextField(
                      _codDiscountController,
                      'Additional notes for COD discount (Optional)',
                      TextInputType.text,
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text('Delivery Type', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                  CheckboxListTile(
                    title: Text(
                      'Express Delivery',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: _isPastExpressCutoff ? Colors.grey : Colors.black,
                      ),
                    ),
                    subtitle: Text(
                      _isPastExpressCutoff
                          ? 'Not available. Cutoff time was ${_settings['express_cutoff_time'] ?? '12:00 PM'}'
                          : 'Add \$${_settings['express_delivery_fee'] ?? '50.00'} for same-day delivery. Must order before ${_settings['express_cutoff_time'] ?? '12:00 PM'}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w300,
                        color: _isPastExpressCutoff ? Colors.red[300] : Colors.grey,
                      ),
                    ),
                    value: _isExpress && !_isPastExpressCutoff,
                    onChanged: _isPastExpressCutoff
                        ? null
                        : (val) {
                            setState(() => _isExpress = val ?? false);
                          },
                    activeColor: Theme.of(context).primaryColor,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: _agreedToTerms,
                        onChanged: (val) => setState(() => _agreedToTerms = val ?? false),
                        activeColor: Theme.of(context).primaryColor,
                      ),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: 'I agree to the ',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300),
                            children: [
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: GestureDetector(
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PolicyView(title: 'Terms & Conditions', content: AppConstants.termsAndConditions))),
                                  child: Text(
                                    'Terms & Conditions',
                                    style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                                  ),
                                ),
                              ),
                              const TextSpan(text: ' and '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: GestureDetector(
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PolicyView(title: 'Privacy Policy', content: AppConstants.privacyPolicy))),
                                  child: Text(
                                    'Privacy Policy',
                                    style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        color: Colors.white,
        child: ElevatedButton(
          onPressed: _proceedToConfirmation,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: Theme.of(context).primaryColor,
            elevation: 0,
          ),
          child: const Text('Review Order', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildSmallTextField(TextEditingController controller, String label, TextInputType type) {
    return TextField(
      controller: controller,
      keyboardType: type,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w300),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300, color: Colors.grey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      ),
    );
  }

  Widget _buildPaymentMethodCard(String value, String title, String subtitle, IconData icon) {
    bool isSelected = _paymentMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFDFCF0) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [BoxShadow(color: Theme.of(context).primaryColor.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))] : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : const Color(0xFFF8FAFC),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? Theme.of(context).primaryColor : const Color(0xFF64748B), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, fontSize: 13)),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w300)),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: Theme.of(context).primaryColor, size: 20)
            else
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
