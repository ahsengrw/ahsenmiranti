import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../models/order.dart';
import '../../services/notification_service.dart';
import '../../core/constants.dart';
import 'chat_screen.dart';

class TrackingView extends StatefulWidget {
  const TrackingView({Key? key}) : super(key: key);

  @override
  State<TrackingView> createState() => _TrackingViewState();
}

class _TrackingViewState extends State<TrackingView> with SingleTickerProviderStateMixin {
  Order? _activeOrder;
  Timer? _timer;
  bool _isLoading = true;
  GoogleMapController? _mapController;
  late AnimationController _pulseController;
  List<LatLng> _routePoints = [];
  int? _userId;
  String? _lastNotifiedStatus;
  int? _lastNotifiedOrderId;
  BitmapDescriptor? _carIcon;
  String _distance = "";
  String _duration = "";

  static const String _mapStyle = '[{"elementType":"geometry","stylers":[{"color":"#f5f5f5"}]},{"elementType":"labels.icon","stylers":[{"visibility":"off"}]},{"elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},{"elementType":"labels.text.stroke","stylers":[{"color":"#f5f5f5"}]},{"featureType":"administrative.land_parcel","elementType":"labels.text.fill","stylers":[{"color":"#bdbdbd"}]},{"featureType":"poi","elementType":"geometry","stylers":[{"color":"#eeeeee"}]},{"featureType":"poi","labels.text.fill","stylers":[{"color":"#757575"}]},{"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#e5e5e5"}]},{"featureType":"poi.park","labels.text.fill","stylers":[{"color":"#9e9e9e"}]},{"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},{"featureType":"road.arterial","labels.text.fill","stylers":[{"color":"#757575"}]},{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#dadada"}]},{"featureType":"road.highway","labels.text.fill","stylers":[{"color":"#616161"}]},{"featureType":"road.local","labels.text.fill","stylers":[{"color":"#9e9e9e"}]},{"featureType":"transit.line","elementType":"geometry","stylers":[{"color":"#e5e5e5"}]},{"featureType":"transit.station","elementType":"geometry","stylers":[{"color":"#eeeeee"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#c9c9c9"}]},{"featureType":"water","labels.text.fill","stylers":[{"color":"#9e9e9e"}]}]';

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
    _initUserAndFetch();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) => _fetchActiveOrder());
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadMarkerIcons() async {
    _carIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/images/car.png',
    );
  }

  Future<void> _initUserAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(AppConstants.keyUserData);
    if (userData != null) {
      final user = jsonDecode(userData);
      setState(() => _userId = user['id']);
    }
    _fetchActiveOrder();
  }

  Future<void> _fetchActiveOrder() async {
    if (_userId == null) return;
    try {
      final response = await ApiService.get('orders?customer_id=$_userId');
      if (response['success'] == true) {
        final List data = response['data'];
        final orders = data.map((json) => Order.fromJson(json)).toList();
        
        final active = orders.where((o) => 
          o.status == 'pending' || 
          o.status == 'assigned' || 
          o.status == 'out_for_delivery'
        ).toList();
        
        if (mounted) {
          final Order? newActive = active.isNotEmpty ? active.first : null;

          if (newActive != null) {
            if (_lastNotifiedOrderId == newActive.id && _lastNotifiedStatus != null && _lastNotifiedStatus != newActive.status) {
              NotificationService.showNotification(
                'Order Update', 
                'Order #${newActive.id} is now ${newActive.status.replaceAll('_', ' ')}'
              );
            }
            _lastNotifiedOrderId = newActive.id;
            _lastNotifiedStatus = newActive.status;
          }

          setState(() {
            _activeOrder = newActive;
            _isLoading = false;
          });
          
          if (_activeOrder != null) {
            _getRoute();
            if (_activeOrder!.driverLat != null) {
               _mapController?.animateCamera(CameraUpdate.newLatLng(LatLng(_activeOrder!.driverLat!, _activeOrder!.driverLng!)));
            } else if (_activeOrder!.deliveryLat != null) {
               _mapController?.animateCamera(CameraUpdate.newLatLng(LatLng(_activeOrder!.deliveryLat!, _activeOrder!.deliveryLng!)));
            }
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _getRoute() async {
    if (_activeOrder == null || _activeOrder!.deliveryLat == null || _activeOrder!.driverLat == null) {
      setState(() => _routePoints = []);
      return;
    }

    try {
      final String url = 'https://maps.googleapis.com/maps/api/directions/json?origin=${_activeOrder!.driverLat},${_activeOrder!.driverLng}&destination=${_activeOrder!.deliveryLat},${_activeOrder!.deliveryLng}&key=${AppConstants.googleMapsApiKey}';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'].isNotEmpty) {
          final points = PolylinePoints().decodePolyline(data['routes'][0]['overview_polyline']['points']);
          final leg = data['routes'][0]['legs'][0];
          setState(() {
            _routePoints = points.map((p) => LatLng(p.latitude, p.longitude)).toList();
            _distance = leg['distance']['text'];
            _duration = leg['duration']['text'];
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching route in customer tracking: $e");
    }
  }

  bool _isOutsideHours() {
    final now = DateTime.now();
    return now.hour < 9 || now.hour >= 17;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    if (_activeOrder == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No active deliveries at the moment.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    bool showAfterHoursMessage = _activeOrder!.status == 'pending' && !_activeOrder!.isExpress && _isOutsideHours();

    if (showAfterHoursMessage) {
      return _buildAfterHoursState();
    }

    if (_activeOrder!.status == 'pending') {
      return _buildPendingState();
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _activeOrder!.driverLat != null 
                ? LatLng(_activeOrder!.driverLat!, _activeOrder!.driverLng!) 
                : LatLng(_activeOrder!.deliveryLat!, _activeOrder!.deliveryLng!),
            zoom: 13,
          ),
          style: _mapStyle,
          onMapCreated: (controller) {
            _mapController = controller;
          },
          markers: {
            if (_activeOrder!.deliveryLat != null)
              Marker(
                markerId: const MarkerId('customer'),
                position: LatLng(_activeOrder!.deliveryLat!, _activeOrder!.deliveryLng!),
                infoWindow: const InfoWindow(title: 'Delivery Location'),
              ),
            if (_activeOrder!.driverLat != null)
              Marker(
                markerId: const MarkerId('driver'),
                position: LatLng(_activeOrder!.driverLat!, _activeOrder!.driverLng!),
                icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                anchor: const Offset(0.5, 0.5),
                infoWindow: const InfoWindow(title: 'Driver Location'),
              ),
          },
          polylines: {
            if (_routePoints.isNotEmpty)
              Polyline(
                polylineId: const PolylineId('route'),
                color: const Color(0xFFB91C1C),
                points: _routePoints,
                width: 5,
              ),
          },
          myLocationEnabled: false,
          zoomControlsEnabled: false,
        ),
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: Card(
            elevation: 8,
            shadowColor: Colors.black26,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _activeOrder!.status == 'assigned' ? 'Driver is preparing...' : 'Order is on the way!',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A2C2A).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('Order #${_activeOrder!.id}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A2C2A), fontSize: 12)),
                      ),
                    ],
                  ),
                  if (_distance.isNotEmpty && _duration.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.timer_outlined, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text('$_duration ($_distance away)', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w300)),
                        ],
                      ),
                    ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: const Color(0xFFF1F5F9),
                            backgroundImage: _activeOrder!.driverImage != null ? NetworkImage(_activeOrder!.driverImage!) : null,
                            child: _activeOrder!.driverImage == null ? const Icon(Icons.person, color: Color(0xFF4A2C2A)) : null,
                          ),
                          if (_activeOrder!.driverVerified)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                                child: const Icon(Icons.check, color: Colors.white, size: 10),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_activeOrder!.driverName ?? 'Driver', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('Van #${_activeOrder!.driverVan ?? '1'}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(orderId: _activeOrder!.id, otherUserName: _activeOrder!.driverName ?? 'Driver')));
                        },
                        icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF4A2C2A)),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFFDFCF0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildAfterHoursState() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFDFCF0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.nightlight_round, size: 80, color: Color(0xFF4A2C2A)),
          const SizedBox(height: 32),
          const Text(
            'Order Placed Successfully!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF4A2C2A)),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Our delivery team operates from 9 AM to 5 PM. Your order is scheduled for delivery tomorrow morning.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16, height: 1.5),
            ),
          ),
          const SizedBox(height: 40),
          _buildInfoCard(),
        ],
      ),
    );
  }

  Widget _buildPendingState() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 120 * _pulseController.value + 100,
                    height: 120 * _pulseController.value + 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF4A2C2A).withOpacity(1 - _pulseController.value),
                    ),
                  );
                },
              ),
              const Icon(Icons.search, size: 80, color: Color(0xFF4A2C2A)),
            ],
          ),
          const SizedBox(height: 40),
          const Text(
            'Finding a Delivery Driver',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'We are currently looking for a driver nearby to deliver your beading.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.5),
            ),
          ),
          const SizedBox(height: 40),
          _buildInfoCard(),
          const SizedBox(height: 30),
          const CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4A2C2A)),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _buildOrderSummaryRow('Order ID', '#${_activeOrder!.id}'),
          const Divider(height: 20),
          _buildOrderSummaryRow('Total Amount', '\$${_activeOrder!.totalAmount.toStringAsFixed(2)}'),
          const Divider(height: 20),
          _buildOrderSummaryRow('Delivery Type', _activeOrder!.isExpress ? 'Express' : 'Standard'),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
