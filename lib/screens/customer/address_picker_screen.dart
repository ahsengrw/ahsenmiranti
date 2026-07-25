import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../core/constants.dart';

class AddressPickerScreen extends StatefulWidget {
  const AddressPickerScreen({super.key});

  @override
  State<AddressPickerScreen> createState() => _AddressPickerScreenState();
}

class _AddressPickerScreenState extends State<AddressPickerScreen> {
  final _addressController = TextEditingController();
  final _additionalController = TextEditingController();
  LatLng _selectedLocation = const LatLng(-34.9285, 138.6007); // Adelaide
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  bool _isLoading = false;
  int? _userId;

  static const String _mapStyle = '[{"elementType":"geometry","stylers":[{"color":"#f5f5f5"}]},{"elementType":"labels.icon","stylers":[{"visibility":"off"}]},{"elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},{"elementType":"labels.text.stroke","stylers":[{"color":"#f5f5f5"}]},{"featureType":"administrative.land_parcel","elementType":"labels.text.fill","stylers":[{"color":"#bdbdbd"}]},{"featureType":"poi","elementType":"geometry","stylers":[{"color":"#eeeeee"}]},{"featureType":"poi","labels.text.fill","stylers":[{"color":"#757575"}]},{"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#e5e5e5"}]},{"featureType":"poi.park","labels.text.fill","stylers":[{"color":"#9e9e9e"}]},{"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},{"featureType":"road.arterial","labels.text.fill","stylers":[{"color":"#757575"}]},{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#dadada"}]},{"featureType":"road.highway","labels.text.fill","stylers":[{"color":"#616161"}]},{"featureType":"road.local","labels.text.fill","stylers":[{"color":"#9e9e9e"}]},{"featureType":"transit.line","elementType":"geometry","stylers":[{"color":"#e5e5e5"}]},{"featureType":"transit.station","elementType":"geometry","stylers":[{"color":"#eeeeee"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#c9c9c9"}]},{"featureType":"water","labels.text.fill","stylers":[{"color":"#9e9e9e"}]}]';

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  Future<void> _loadCurrentData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataStr = prefs.getString(AppConstants.keyUserData);
    if (userDataStr != null) {
      final userData = jsonDecode(userDataStr);
      setState(() {
        _userId = userData['id'];
        _addressController.text = userData['address'] ?? '';
        if (userData['lat'] != null && userData['lng'] != null) {
          _selectedLocation = LatLng(
            double.parse(userData['lat'].toString()),
            double.parse(userData['lng'].toString()),
          );
          _updateMarker(_selectedLocation);
        }
      });
    }
  }

  void _updateMarker(LatLng position) {
    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('selected-location'),
          position: position,
        ),
      );
    });
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<geo.Placemark> placemarks = await geo.placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        geo.Placemark place = placemarks[0];
        String address = "${place.street}, ${place.locality}, ${place.postalCode}, ${place.country}";
        setState(() {
          _addressController.text = address;
        });
      }
    } catch (e) {
      debugPrint("Geocoding error: $e");
    }
  }

  Future<void> _saveAddress() async {
    if (_userId == null || _addressController.text.isEmpty) return;

    setState(() => _isLoading = true);

    String finalAddress = _addressController.text.trim();
    if (_additionalController.text.isNotEmpty) {
      finalAddress = "$finalAddress - ${_additionalController.text.trim()}";
    }

    try {
      final success = await AuthService.updateAddress(
        _userId!,
        finalAddress,
        _selectedLocation.latitude,
        _selectedLocation.longitude,
      );

      if (success && mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCF0),
      appBar: AppBar(
        title: const Text('Update Delivery Address'),
        backgroundColor: const Color(0xFF4A2C2A),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(target: _selectedLocation, zoom: 15),
                  style: _mapStyle,
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  markers: _markers,
                  onTap: (LatLng position) {
                    setState(() => _selectedLocation = position);
                    _updateMarker(position);
                    _getAddressFromLatLng(position);
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                ),
                Positioned(
                  top: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                    ),
                    child: GooglePlaceAutoCompleteTextField(
                      textEditingController: _addressController,
                      googleAPIKey: AppConstants.googleMapsApiKey,
                      inputDecoration: InputDecoration(
                        hintText: 'Search for address...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      debounceTime: 600,
                      countries: const ["au"],
                      isLatLngRequired: true,
                      getPlaceDetailWithLatLng: (Prediction prediction) {
                        if (prediction.lat != null && prediction.lng != null) {
                          setState(() {
                            _selectedLocation = LatLng(double.parse(prediction.lat!), double.parse(prediction.lng!));
                            _updateMarker(_selectedLocation);
                          });
                          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_selectedLocation, 17));
                        }
                      },
                      itemClick: (Prediction prediction) {
                        _addressController.text = prediction.description ?? "";
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _additionalController,
                  decoration: InputDecoration(
                    labelText: 'Apt, Suite, Floor (Optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveAddress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB91C1C),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Update & Use Address', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
