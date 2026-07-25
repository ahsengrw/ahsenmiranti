import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/product.dart';
import '../../services/api_service.dart';
import 'checkout_screen.dart';
import '../../models/order.dart';
import '../../core/constants.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  List<Product> _products = [];
  bool _isLoading = true;
  Product? _selectedProduct;
  Order? _lastOrder;
  String _userAddress = "Loading address...";
  Map<String, dynamic> _settings = {};
  int? _userId;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    await _loadUserInfo();
    await Future.wait([
      _fetchProducts(),
      _fetchLastOrder(),
      _fetchSettings(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(AppConstants.keyUserData);
    if (userData != null) {
      final user = jsonDecode(userData);
      setState(() {
        _userId = user['id'];
        _userAddress = user['address'] ?? 'Set your address in profile';
      });
    }
  }

  Future<void> _fetchSettings() async {
    try {
      final response = await ApiService.get('settings');
      if (response['success'] == true) {
        setState(() => _settings = response['data']);
      }
    } catch (e) {}
  }

  Future<void> _fetchProducts() async {
    try {
      final response = await ApiService.get('products');
      if (response['success'] == true) {
        final list = (response['data'] as List).map((json) => Product.fromJson(json)).toList();
        setState(() {
          _products = list;
          if (_products.isNotEmpty) {
            _selectedProduct = _products.first;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching products: $e');
    }
  }

  Future<void> _fetchLastOrder() async {
    if (_userId == null) return;
    try {
      final response = await ApiService.get('orders?customer_id=$_userId');
      if (response['success'] == true) {
        final list = (response['data'] as List).map((json) => Order.fromJson(json)).toList();
        if (list.isNotEmpty) {
          setState(() => _lastOrder = list.first);
        }
      }
    } catch (e) {
      debugPrint('Error fetching last order: $e');
    }
  }

  void _navigateToCheckout(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CheckoutScreen(product: product)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: const Color(0xFFFDFCF0),
      body: SafeArea(
        child: Column(
          children: [
            _buildStickyHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroSection(),
                    if (_lastOrder != null) _buildOneTapOrder(),
                    _buildProductSection(),
                    _buildFeaturesSection(),
                    _buildClosingMessage(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFCF0).withOpacity(0.95),
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Delivering to', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w300)),
                GestureDetector(
                  onTap: () {}, // Trigger address change
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          _userAddress,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF321F1E)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down, size: 14, color: Color(0xFF321F1E)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF4A2C2A).withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Stack(
              children: [
                const Icon(Icons.notifications_none, color: Color(0xFF4A2C2A), size: 22),
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFDFCF0),
                        width: 1.5,
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    final bannerUrl = _settings['hero_banner_url'];
    final welcomeDesc = _settings['welcome_description'] ?? 'Adelaide\'s dedicated Meranti beading delivery service.';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  bannerUrl != null && bannerUrl.isNotEmpty
                      ? Image.network(bannerUrl, fit: BoxFit.cover)
                      : Image.network('https://images.unsplash.com/photo-1519003722824-194d4455a60c?auto=format&fit=crop&w=800&q=80', fit: BoxFit.cover),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, const Color(0xFF321F1E).withOpacity(0.9)],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ADELAIDE\'S DEDICATED SERVICE', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1)),
                        const SizedBox(height: 4),
                        const Text('Welcome to SA Meranti Beading Today', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            welcomeDesc,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.6, fontWeight: FontWeight.w300),
          ),
        ],
      ),
    );
  }

  Widget _buildOneTapOrder() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF4A2C2A),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: const Color(0xFF4A2C2A).withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.history, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ORDER AGAIN', style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  Text(
                    _lastOrder?.itemsSummary ?? 'Meranti Beading',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (_products.isNotEmpty) _navigateToCheckout(_products.first);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF4A2C2A),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text('1-Tap Order', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductSection() {
    if (_selectedProduct == null) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Our Product', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.withOpacity(0.05)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProductGallery(),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Premium Meranti Beading', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                              const SizedBox(height: 2),
                              Text('${_selectedProduct!.sizeMm} mm × 14 mm', style: const TextStyle(color: Color(0xFF4A2C2A), fontSize: 13, fontWeight: FontWeight.w500)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.widgets_outlined, color: Color(0xFFD97706), size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('Sold exclusively in bundles of 40 sticks. Perfect for professional finishing.', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, height: 1.5, fontWeight: FontWeight.w300)),
                      const SizedBox(height: 24),
                      const Text('SELECT LENGTH', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1F2937), letterSpacing: 0.5)),
                      const SizedBox(height: 12),
                      Row(
                        children: _products.map((p) => Expanded(child: _buildLengthOption(p))).toList(),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('\$${(_selectedProduct!.price * 1.1).toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF94A3B8), decoration: TextDecoration.lineThrough, fontSize: 12, fontWeight: FontWeight.w300)),
                                Row(
                                  children: [
                                    Text('\$${_selectedProduct!.price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF321F1E))),
                                    const Text(' / bundle', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w300)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _navigateToCheckout(_selectedProduct!),
                            icon: const Icon(Icons.bolt, size: 18),
                            label: const Text('Buy Now'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4A2C2A),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 8,
                              shadowColor: const Color(0xFF4A2C2A).withOpacity(0.3),
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
        ],
      ),
    );
  }

  Widget _buildProductGallery() {
    final images = _selectedProduct!.imageUrls;
    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          images.isEmpty
              ? Center(child: Image.asset('assets/images/product.png', width: 150))
              : PageView.builder(
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(images[index], fit: BoxFit.cover),
                      ),
                    );
                  },
                ),
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 12),
                  const SizedBox(width: 4),
                  Text('${_selectedProduct!.stockQuantity} Left in Stock', style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 10)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLengthOption(Product p) {
    bool isSelected = _selectedProduct?.id == p.id;
    return GestureDetector(
      onTap: () => setState(() => _selectedProduct = p),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A2C2A).withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFF4A2C2A) : const Color(0xFFE5E7EB), width: 1.5),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                Text('${(p.sizeMm / 1000).toStringAsFixed(1)} Metres', style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontSize: 12, color: isSelected ? const Color(0xFF321F1E) : const Color(0xFF6B7280))),
                const SizedBox(height: 2),
                const Text('40 Sticks/Bundle', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 8)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(color: p.stockQuantity < 10 ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(4)),
                  child: Text('${p.stockQuantity} Left', textAlign: TextAlign.center, style: TextStyle(color: p.stockQuantity < 10 ? const Color(0xFFC2410C) : const Color(0xFF15803D), fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            if (isSelected)
              Positioned(
                top: -18,
                right: -18,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Color(0xFF4A2C2A), shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: Colors.white, size: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Fast Ordering & Delivery', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
          const SizedBox(height: 8),
          const Text('Create your account once and enjoy one-tap reordering, saved order history, fast checkout and live order tracking.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.5, fontWeight: FontWeight.w300)),
          const SizedBox(height: 20),
          _buildFeatureCard(Icons.bolt, 'Delivery Options', 'Choose Standard Delivery or Express Delivery (subject to availability and cut-off times).', const Color(0xFFEFF6FF), const Color(0xFF3B82F6)),
          const SizedBox(height: 12),
          _buildTrackingFeatureCard(),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String desc, Color bgColor, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF3F4F6))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 24)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1F2937))),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingFeatureCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF3F4F6))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 48, height: 48, decoration: const BoxDecoration(color: Color(0xFFF0FDF4), shape: BoxShape.circle), child: const Icon(Icons.map_outlined, color: Color(0xFF22C55E), size: 24)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Live GPS Tracking', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1F2937))),
                const SizedBox(height: 4),
                const Text('Live GPS tracking lets customers see the delivery vehicle and estimated arrival time.', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, height: 1.4)),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Image.network('https://images.unsplash.com/photo-1524661135-423995f22d0b?auto=format&fit=crop&w=400&q=80', height: 80, width: double.infinity, fit: BoxFit.cover),
                      Container(height: 80, color: const Color(0xFF4A2C2A).withOpacity(0.1)),
                      const Positioned.fill(child: Center(child: Icon(Icons.local_shipping, color: Color(0xFF4A2C2A), size: 24))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClosingMessage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7).withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFEF3C7)),
        ),
        child: Column(
          children: [
            const Icon(Icons.handshake_outlined, color: Color(0xFFF59E0B), size: 32),
            const SizedBox(height: 8),
            const Text(
              '"Thank you for choosing SA Meranti Beading Today. We look forward to providing premium products, professional service and fast, reliable deliveries throughout metropolitan Adelaide."',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.6, fontWeight: FontWeight.w500, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}
