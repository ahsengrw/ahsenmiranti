import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../models/order.dart';
import '../../services/api_service.dart';
import '../../core/constants.dart';

class ActiveOrderView extends StatefulWidget {
  final Order order;
  const ActiveOrderView({super.key, required this.order});

  @override
  State<ActiveOrderView> createState() => _ActiveOrderViewState();
}

class _ActiveOrderViewState extends State<ActiveOrderView> {
  LatLng? _driverLocation;
  LatLng? _customerLocation;
  Timer? _locationTimer;
  GoogleMapController? _mapController;
  bool _isDelivering = false;
  List<LatLng> _routePoints = [];
  BitmapDescriptor? _carIcon;

  static const String _mapStyle = '[{"elementType":"geometry","stylers":[{"color":"#f5f5f5"}]},{"elementType":"labels.icon","stylers":[{"visibility":"off"}]},{"elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},{"elementType":"labels.text.stroke","stylers":[{"color":"#f5f5f5"}]},{"featureType":"administrative.land_parcel","elementType":"labels.text.fill","stylers":[{"color":"#bdbdbd"}]},{"featureType":"poi","elementType":"geometry","stylers":[{"color":"#eeeeee"}]},{"featureType":"poi","labels.text.fill","stylers":[{"color":"#757575"}]},{"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#e5e5e5"}]},{"featureType":"poi.park","labels.text.fill","stylers":[{"color":"#9e9e9e"}]},{"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},{"featureType":"road.arterial","labels.text.fill","stylers":[{"color":"#757575"}]},{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#dadada"}]},{"featureType":"road.highway","labels.text.fill","stylers":[{"color":"#616161"}]},{"featureType":"road.local","labels.text.fill","stylers":[{"color":"#9e9e9e"}]},{"featureType":"transit.line","elementType":"geometry","stylers":[{"color":"#e5e5e5"}]},{"featureType":"transit.station","elementType":"geometry","stylers":[{"color":"#eeeeee"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#c9c9c9"}]},{"featureType":"water","labels.text.fill","stylers":[{"color":"#9e9e9e"}]}]';

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
    if (widget.order.deliveryLat != null && widget.order.deliveryLng != null) {
      _customerLocation = LatLng(widget.order.deliveryLat!, widget.order.deliveryLng!);
    }
    _initializeLocationTracking();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMarkerIcons() async {
    _carIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/images/car.png',
    );
  }

  Future<void> _initializeLocationTracking() async {
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

      Position initialPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _driverLocation = LatLng(initialPosition.latitude, initialPosition.longitude);
      });
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_driverLocation!, 14));
      _getRoute();
    } catch (e) {
      debugPrint("Error initializing location tracking: $e");
      _setFallbackLocation();
    }

    _startLocationPing();
  }

  void _setFallbackLocation() {
    if (mounted) {
      setState(() {
        _driverLocation = const LatLng(-34.9285, 138.6007);
      });
    }
  }

  void _startLocationPing() {
    _locationTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (!mounted) return;
      try {
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        setState(() {
          _driverLocation = LatLng(position.latitude, position.longitude);
        });
        _sendLocationToServer(position.latitude, position.longitude);
        _getRoute();
      } catch (e) {
        debugPrint('Location ping failed: $e');
      }
    });
  }

  Future<void> _getRoute() async {
    if (_driverLocation == null || _customerLocation == null) return;

    try {
      PolylinePoints polylinePoints = PolylinePoints();
      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: AppConstants.googleMapsApiKey,
        request: PolylineRequest(
          origin: PointLatLng(_driverLocation!.latitude, _driverLocation!.longitude),
          destination: PointLatLng(_customerLocation!.latitude, _customerLocation!.longitude),
          mode: TravelMode.driving,
        ),
      );

      if (result.points.isNotEmpty) {
        setState(() {
          _routePoints = result.points.map((p) => LatLng(p.latitude, p.longitude)).toList();
        });
      }
    } catch (e) {
      debugPrint("Error fetching route in active order: $e");
    }
  }

  Future<void> _sendLocationToServer(double lat, double lng) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = jsonDecode(prefs.getString(AppConstants.keyUserData) ?? '{}');

      if (userData['id'] != null) {
        await ApiService.put('orders?action=location', {
          'driver_id': userData['id'],
          'lat': lat,
          'lng': lng,
        });
      }
    } catch (e) {
      debugPrint('Location sync failed: $e');
    }
  }

  Future<void> _markAsDelivered() async {
    setState(() => _isDelivering = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = jsonDecode(prefs.getString(AppConstants.keyUserData) ?? '{}');

      await ApiService.put('orders', {
        'order_id': widget.order.id,
        'status': 'delivered',
        'driver_id': userData['id']
      });

      _locationTimer?.cancel();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery completed successfully!'), backgroundColor: Colors.green));
      Navigator.pop(context, true); 
    } catch (e) {
      setState(() => _isDelivering = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update status.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text('Order #${widget.order.id}'),
        backgroundColor: const Color(0xFF4A2C2A),
      ),
      body: Column(
        children: [
          Expanded(
            child: _driverLocation == null
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFB91C1C)))
                : GoogleMap(
              onMapCreated: (c) {
                _mapController = c;
              },
              initialCameraPosition: CameraPosition(target: _driverLocation!, zoom: 14),
              style: _mapStyle,
              markers: {
                Marker(
                  markerId: const MarkerId('driver'), 
                  position: _driverLocation!, 
                  icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                  anchor: const Offset(0.5, 0.5),
                ),
                if (_customerLocation != null)
                  Marker(markerId: const MarkerId('cust'), position: _customerLocation!),
              },
              polylines: {
                if (_routePoints.isNotEmpty)
                  Polyline(polylineId: const PolylineId('route'), points: _routePoints, color: const Color(0xFFB91C1C), width: 5),
              },
              myLocationEnabled: false,
              zoomControlsEnabled: false,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Customer: ${widget.order.customerName}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Total: \$${widget.order.totalAmount.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF10B981), fontSize: 16)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isDelivering ? null : _markAsDelivered,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB91C1C),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isDelivering
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Complete Delivery', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
