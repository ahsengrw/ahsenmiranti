import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/order.dart';
import '../../services/api_service.dart';
import '../../services/invoice_service.dart';
import '../../models/product.dart';
import '../../core/constants.dart';
import 'checkout_screen.dart';

class HistoryView extends StatefulWidget {
  const HistoryView({Key? key}) : super(key: key);

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  List<Order> _orders = [];
  bool _isLoading = true;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _initUserAndFetch();
  }

  Future<void> _initUserAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(AppConstants.keyUserData);
    if (userData != null) {
      final user = jsonDecode(userData);
      setState(() => _userId = user['id']);
    }
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    if (_userId == null) return;
    try {
      final response = await ApiService.get('orders?customer_id=$_userId');
      if (response['success'] == true) {
        final List data = response['data'];
        setState(() {
          _orders = data.map((json) => Order.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load history')));
      }
    }
  }

  void _reorder(Order order) async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('products');
      if (response['success'] == true) {
        final products = (response['data'] as List).map((json) => Product.fromJson(json)).toList();
        
        Product? match;
        if (products.isNotEmpty) {
           match = products.first; 
        }

        if (match != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CheckoutScreen(product: match!)),
          );
        }
      }
    } catch (e) {
      debugPrint("Reorder fail: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_orders.isEmpty) {
      return const Center(child: Text('No past orders found.', style: TextStyle(color: Colors.grey)));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFDFCF0),
      appBar: AppBar(
        title: const Text('Order History', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF4A2C2A),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchHistory,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _orders.length,
          itemBuilder: (context, index) {
            final order = _orders[index];
            final isDelivered = order.status == 'delivered';

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDelivered ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            order.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDelivered ? Colors.green : Colors.blue,
                            ),
                          ),
                        ),
                        Text(
                          '\$${order.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Order #ORD-${order.id}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.itemsSummary ?? 'Bundles of Beading',
                      style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Date: ${DateTime.parse(order.createdAt).toLocal().toString().split('.')[0]}',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => InvoiceService.generateAndShare(order),
                            icon: const Icon(Icons.picture_as_pdf, size: 16),
                            label: const Text('Invoice', style: TextStyle(color: Color(0xFF475569))),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _reorder(order),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFB91C1C),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            child: const Text('Reorder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
