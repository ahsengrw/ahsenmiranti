import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/order.dart';
import '../../models/user.dart';
import '../../core/constants.dart';
import '../auth/welcome_screen.dart';
import 'proof_of_delivery_screen.dart';
import '../../services/notification_service.dart';
import '../customer/chat_screen.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({Key? key}) : super(key: key);

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  List<Order> _pendingOrders = [];
  Order? _activeOrder;
  bool _isLoading = true;
  User? _currentUser;
  bool _isOnline = true;
  int _unreadCount = 0;

  Timer? _pollingTimer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _highestKnownOrderId = 0;

  LatLng? _driverLocation;
  GoogleMapController? _mapController;
  List<LatLng> _routePoints = [];
  bool _isMapFullScreen = false;
  BitmapDescriptor? _carIcon;

  static const String _mapStyle = '[{"elementType":"geometry","stylers":[{"color":"#f5f5f5"}]},{"elementType":"labels.icon","stylers":[{"visibility":"off"}]},{"elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},{"elementType":"labels.text.stroke","stylers":[{"color":"#f5f5f5"}]},{"featureType":"administrative.land_parcel","elementType":"labels.text.fill","stylers":[{"color":"#bdbdbd"}]},{"featureType":"poi","elementType":"geometry","stylers":[{"color":"#eeeeee"}]},{"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},{"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#e5e5e5"}]},{"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},{"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},{"featureType":"road.arterial","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#dadada"}]},{"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},{"featureType":"road.local","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},{"featureType":"transit.line","elementType":"geometry","stylers":[{"color":"#e5e5e5"}]},{"featureType":"transit.station","elementType":"geometry","stylers":[{"color":"#eeeeee"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#c9c9c9"}]},{"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]}]';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadMarkerIcons();
    _initializeLocation();
    _fetchOrders(initialLoad: true);
    _startRealtimePolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadMarkerIcons() async {
    _carIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/images/car.png', // Fallback to splash if car icon is not available, or use a specific one
    );
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(AppConstants.keyUserData);
    if (userData != null) {
      setState(() {
        _currentUser = User.fromJson(jsonDecode(userData));
      });
    }
  }

  Future<void> _initializeLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setFallbackLocation();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _setFallbackLocation();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _setFallbackLocation();
        return;
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _driverLocation = LatLng(position.latitude, position.longitude);
        });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_driverLocation!, 14));
        _getRoute();
      }
    } catch (e) {
      debugPrint("Error initializing location: $e");
      _setFallbackLocation();
    }
    _startLocationPing();
  }

  void _setFallbackLocation() {
    if (mounted) {
      setState(() {
        _driverLocation = const LatLng(-34.9285, 138.6007); // Adelaide
      });
    }
  }

  void _startLocationPing() {
    Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_isOnline) return;
      try {
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        setState(() {
          _driverLocation = LatLng(position.latitude, position.longitude);
        });

        final prefs = await SharedPreferences.getInstance();
        final userData = jsonDecode(prefs.getString(AppConstants.keyUserData) ?? '{}');
        if (userData['id'] != null) {
          await ApiService.put('orders?action=location', {
            'driver_id': userData['id'],
            'lat': position.latitude,
            'lng': position.longitude,
          });
        }
        if (_activeOrder != null) _getRoute();
      } catch (e) {
        debugPrint('Location ping failed: $e');
      }
    });
  }

  void _startRealtimePolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchOrders(initialLoad: false);
      _fetchUnreadCount();
    });
  }

  Future<void> _fetchUnreadCount() async {
    if (_currentUser == null) return;
    try {
      final response = await ApiService.get('messages?action=unread&user_id=${_currentUser!.id}');
      if (response['success'] == true) {
        setState(() => _unreadCount = response['data']['unread']);
      }
    } catch (e) {
      debugPrint('Unread fetch error: $e');
    }
  }

  Future<void> _fetchOrders({required bool initialLoad}) async {
    try {
      final response = await ApiService.get('orders');
      if (response['success'] == true) {
        final List data = response['data'];
        final allOrders = data.map((json) => Order.fromJson(json)).toList();

        final pending = allOrders.where((o) => o.status == 'pending').toList();
        pending.sort((a, b) {
          if (a.isExpress && !b.isExpress) return -1;
          if (!a.isExpress && b.isExpress) return 1;
          return b.createdAt.compareTo(a.createdAt);
        });

        final prefs = await SharedPreferences.getInstance();
        final userData = jsonDecode(prefs.getString(AppConstants.keyUserData) ?? '{}');
        final int? driverId = userData['id'] != null ? int.tryParse(userData['id'].toString()) : null;

        final assigned = allOrders.where((o) => 
          (o.status == 'assigned' || o.status == 'out_for_delivery') && o.driverId == driverId
        ).toList();

        if (mounted) {
          if (!initialLoad && pending.length > _pendingOrders.length) {
            NotificationService.showNotification('New Order', 'A new order is available in your queue');
          }

          final previousActiveId = _activeOrder?.id;
          setState(() {
            _pendingOrders = pending;
            _activeOrder = assigned.isNotEmpty ? assigned.first : null;
            _isLoading = false;
            if (_activeOrder == null) _routePoints = [];
          });

          if (_activeOrder != null && _activeOrder?.id != previousActiveId) {
             _getRoute();
          }

          if (!initialLoad && pending.isNotEmpty) {
            int currentMaxId = pending.map((e) => e.id).reduce((a, b) => a > b ? a : b);
            if (currentMaxId > _highestKnownOrderId) {
              _highestKnownOrderId = currentMaxId;
              _playNewOrderSound();
            }
          } else if (initialLoad && pending.isNotEmpty) {
            _highestKnownOrderId = pending.map((e) => e.id).reduce((a, b) => a > b ? a : b);
          }
        }
      }
    } catch (e) {
      if (mounted && initialLoad) setState(() => _isLoading = false);
    }
  }

  Future<void> _getRoute() async {
    if (_driverLocation == null || _activeOrder == null || _activeOrder!.deliveryLat == null) return;

    try {
      PolylinePoints polylinePoints = PolylinePoints();
      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: AppConstants.googleMapsApiKey,
        request: PolylineRequest(
          origin: PointLatLng(_driverLocation!.latitude, _driverLocation!.longitude),
          destination: PointLatLng(_activeOrder!.deliveryLat!, _activeOrder!.deliveryLng!),
          mode: TravelMode.driving,
        ),
      );

      if (result.points.isNotEmpty) {
        setState(() {
          _routePoints = result.points.map((p) => LatLng(p.latitude, p.longitude)).toList();
        });
      }
    } catch (e) {
      debugPrint("Error fetching route: $e");
    }
  }

  void _playNewOrderSound() async {
    try {
      await _audioPlayer.play(AssetSource('audio/notification.mp3'));
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔔 New Order Available!'),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          )
      );
    } catch (e) {
      debugPrint("Audio play failed: $e");
    }
  }

  Future<void> _updateOrderStatus(int orderId, String status) async {
    final prefs = await SharedPreferences.getInstance();
    final userData = jsonDecode(prefs.getString(AppConstants.keyUserData) ?? '{}');
    setState(() => _isLoading = true);
    try {
      await ApiService.put('orders', {
        'order_id': orderId,
        'status': status,
        'driver_id': userData['id']
      });
      await _fetchOrders(initialLoad: false);
      if (status == 'assigned') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order Accepted! Opening Map...'), backgroundColor: Colors.green));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update status')));
    }
  }

  void _confirmCancelOrder(int orderId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order?'),
        content: const Text('Are you sure you want to cancel this order? This action will inform the admin and customer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('No, Keep Order')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateOrderStatus(orderId, 'cancelled');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel It'),
          ),
        ],
      ),
    );
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
    if (_isMapFullScreen && _activeOrder != null) {
      return _buildFullScreenMap();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFDFCF0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A2C2A)))
          : SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildCurrentDelivery(),
                        const SizedBox(height: 24),
                        _buildQueue(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF4A2C2A),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: _currentUser?.profileImage != null ? NetworkImage(_currentUser!.profileImage!) : null,
                    child: _currentUser?.profileImage == null 
                        ? Text(_currentUser?.name[0].toUpperCase() ?? 'D', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  if (_currentUser?.isVerified == true)
                    Positioned(bottom: 0, right: 0, child: Icon(Icons.verified, color: Colors.blue, size: 16)),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_currentUser?.name ?? 'Driver Name', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Van #${_currentUser?.vanNumber ?? '1'}', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.logout, color: Colors.white, size: 20), onPressed: _handleLogout),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: const Color(0xFF331D1C), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                _buildToggleButton('Online', _isOnline, () => setState(() => _isOnline = true)),
                _buildToggleButton('Offline', !_isOnline, () => setState(() => _isOnline = false)),
                _buildChatButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFB91C1C) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _buildChatButton() {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_activeOrder != null) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(orderId: _activeOrder!.id, otherUserName: _activeOrder!.customerName ?? 'Customer')));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active order to chat')));
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: _unreadCount > 0 ? const Color(0xFFB91C1C) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Chats', style: TextStyle(color: _unreadCount > 0 ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
                if (_unreadCount > 0)
                  Padding(padding: const EdgeInsets.only(left: 6), child: CircleAvatar(radius: 8, backgroundColor: Colors.white, child: Text(_unreadCount.toString(), style: const TextStyle(fontSize: 10, color: Colors.red)))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentDelivery() {
    if (_activeOrder == null) return Container(padding: const EdgeInsets.all(40), child: const Center(child: Text('No active delivery', style: TextStyle(color: Colors.grey))));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CURRENT DELIVERY', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  height: 160,
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(target: _driverLocation ?? const LatLng(-34.9285, 138.6007), zoom: 14),
                        style: _mapStyle,
                        onMapCreated: (c) {
                          _mapController = c;
                        },
                        markers: {
                          Marker(
                            markerId: const MarkerId('driver'), 
                            position: _driverLocation ?? const LatLng(0,0), 
                            icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                            anchor: const Offset(0.5, 0.5),
                          ),
                          if (_activeOrder!.deliveryLat != null)
                            Marker(markerId: MarkerId('cust'), position: LatLng(_activeOrder!.deliveryLat!, _activeOrder!.deliveryLng!)),
                        },
                        polylines: {
                          if (_routePoints.isNotEmpty)
                            Polyline(polylineId: const PolylineId('route'), points: _routePoints, color: const Color(0xFFB91C1C), width: 5),
                        },
                        zoomControlsEnabled: false,
                        myLocationEnabled: false,
                      ),
                      Positioned(top: 10, left: 10, child: IconButton(icon: Icon(Icons.fullscreen, color: Color(0xFF4A2C2A)), onPressed: () => setState(() => _isMapFullScreen = true), style: IconButton.styleFrom(backgroundColor: Colors.white))),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order #ORD-${_activeOrder!.id}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(_activeOrder!.customerName ?? 'Customer', style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 16),
                    Row(children: [Icon(Icons.location_on, color: Colors.red, size: 20), SizedBox(width: 8), Expanded(child: Text(_activeOrder!.customerAddress ?? 'Address'))]),
                    if (_activeOrder!.codNote != null && _activeOrder!.codNote!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red[100]!)),
                        child: Text('COD NOTE: ${_activeOrder!.codNote}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFFDFCF0), borderRadius: BorderRadius.circular(12)), child: Text(_activeOrder!.itemsSummary ?? 'Beading Bundles', style: TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: ElevatedButton.icon(onPressed: () {}, icon: Icon(Icons.near_me), label: Text('Maps'), style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[200], foregroundColor: Colors.black))),
                        const SizedBox(width: 12),
                        Expanded(child: ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProofOfDeliveryScreen(order: _activeOrder!))).then((_) => _fetchOrders(initialLoad: false)), icon: Icon(Icons.camera_alt), label: Text('Arrived'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmCancelOrder(_activeOrder!.id),
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text('Cancel Order'),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: BorderSide(color: Colors.red[200]!)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFullScreenMap() {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _driverLocation ?? const LatLng(-34.9285, 138.6007), zoom: 15),
            style: _mapStyle,
            onMapCreated: (c) {
              _mapController = c;
            },
            markers: {
              Marker(
                markerId: const MarkerId('driver'), 
                position: _driverLocation ?? const LatLng(0,0), 
                icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                anchor: const Offset(0.5, 0.5),
              ),
              if (_activeOrder!.deliveryLat != null)
                Marker(markerId: MarkerId('cust'), position: LatLng(_activeOrder!.deliveryLat!, _activeOrder!.deliveryLng!)),
            },
            polylines: {
              if (_routePoints.isNotEmpty)
                Polyline(polylineId: const PolylineId('route'), points: _routePoints, color: const Color(0xFFB91C1C), width: 5),
            },
          ),
          SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: FloatingActionButton(onPressed: () => setState(() => _isMapFullScreen = false), child: Icon(Icons.arrow_back), backgroundColor: Colors.white, foregroundColor: Colors.black))),
          Positioned(bottom: 30, left: 20, right: 20, child: ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProofOfDeliveryScreen(order: _activeOrder!))).then((_) { setState(() => _isMapFullScreen = false); _fetchOrders(initialLoad: false); }), child: Text('Confirm Arrival'), style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF10B981), padding: EdgeInsets.all(16)))),
        ],
      ),
    );
  }

  Widget _buildQueue() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('QUEUE (${_pendingOrders.length})', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)), const Text('Optimize Route', style: TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.bold, fontSize: 12))]),
        const SizedBox(height: 12),
        ..._pendingOrders.asMap().entries.map((entry) {
          int idx = entry.key; Order order = entry.value;
          return GestureDetector(
            onTap: () => _updateOrderStatus(order.id, 'assigned'),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)]),
              child: Row(children: [
                Container(width: 36, height: 36, decoration: const BoxDecoration(color: Color(0xFFFDFCF0), shape: BoxShape.circle), child: Center(child: Text('${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold)))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Text('Order #ORD-${order.id}', style: const TextStyle(fontWeight: FontWeight.bold)), if (order.isExpress) Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(4)), child: const Text('EXPRESS', style: TextStyle(color: Colors.red, fontSize: 8, fontWeight: FontWeight.bold)))]),
                  Text(order.customerAddress ?? 'Address', style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 1),
                ])),
                ElevatedButton(onPressed: () => _updateOrderStatus(order.id, 'assigned'), child: const Text('Accept', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF4A2C2A))),
              ]),
            ),
          );
        }).toList(),
      ],
    );
  }
}
