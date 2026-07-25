import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import '../../services/auth_service.dart';
import '../../core/constants.dart';
import '../customer/policy_view.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _addressController = TextEditingController();
  final _additionalAddressController = TextEditingController();
  bool _isLoading = false;

  bool _has8Chars = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;
  bool _agreedToTerms = false;

  final Color primaryColor = const Color(0xFF4A2C2A);
  final Color subtitleColor = const Color(0xFF6B7280);
  final Color inputBgColor = const Color(0xFFF9FAFB);
  final Color inputBorderColor = const Color(0xFFE5E7EB);

  LatLng _selectedLocation = const LatLng(-34.9285, 138.6007); // Adelaide
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};

  static const String _mapStyle = '[{"elementType":"geometry","stylers":[{"color":"#f5f5f5"}]},{"elementType":"labels.icon","stylers":[{"visibility":"off"}]},{"elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},{"elementType":"labels.text.stroke","stylers":[{"color":"#f5f5f5"}]},{"featureType":"administrative.land_parcel","elementType":"labels.text.fill","stylers":[{"color":"#bdbdbd"}]},{"featureType":"poi","elementType":"geometry","stylers":[{"color":"#eeeeee"}]},{"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},{"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#e5e5e5"}]},{"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},{"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},{"featureType":"road.arterial","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#dadada"}]},{"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},{"featureType":"road.local","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},{"featureType":"transit.line","elementType":"geometry","stylers":[{"color":"#e5e5e5"}]},{"featureType":"transit.station","elementType":"geometry","stylers":[{"color":"#eeeeee"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#c9c9c9"}]},{"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]}]';

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _selectedLocation = LatLng(position.latitude, position.longitude);
          _updateMarker(_selectedLocation);
        });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_selectedLocation, 15));
      }
    } catch (e) {
      debugPrint("Error getting location: $e");
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

  void _validatePassword(String value) {
    setState(() {
      _has8Chars = value.length >= 8;
      _hasNumber = value.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  Future<void> _handleRegister() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty || _addressController.text.isEmpty) {
      _showError('All fields are required.');
      return;
    }

    if (!_has8Chars || !_hasNumber || !_hasSpecialChar) {
      _showError('Please meet all password requirements.');
      return;
    }

    if (!_agreedToTerms) {
      _showError('You must agree to the Terms & Conditions.');
      return;
    }

    setState(() => _isLoading = true);

    String fullAddress = _addressController.text.trim();
    if (_additionalAddressController.text.isNotEmpty) {
      fullAddress += " - " + _additionalAddressController.text.trim();
    }

    try {
      final success = await AuthService.registerCustomer(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
        fullAddress,
        _selectedLocation.latitude,
        _selectedLocation.longitude,
      );

      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created! Please sign in.'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Go back to login
      }
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _buildTextField(String label, String hint, TextEditingController controller, {bool isPassword = false, int maxLines = 1, Function(String)? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: subtitleColor, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            obscureText: isPassword,
            maxLines: maxLines,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w300),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: subtitleColor, fontSize: 13, fontWeight: FontWeight.w300),
              filled: true,
              fillColor: inputBgColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: inputBorderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: inputBorderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirement(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            color: isMet ? Colors.green : Colors.grey,
            size: 14,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w300,
              color: isMet ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Account',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w400, color: primaryColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Start ordering premium beading today.',
                style: TextStyle(color: subtitleColor, fontSize: 14, fontWeight: FontWeight.w300),
              ),
              const SizedBox(height: 32),

              _buildTextField('FULL NAME', 'e.g. John Doe', _nameController),
              _buildTextField('EMAIL ADDRESS', 'e.g. john@example.com', _emailController),
              
              _buildTextField(
                'PASSWORD', 
                'Create a strong password', 
                _passwordController, 
                isPassword: true,
                onChanged: _validatePassword,
              ),
              
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  children: [
                    _buildRequirement('At least 8 characters', _has8Chars),
                    _buildRequirement('At least 1 number', _hasNumber),
                    _buildRequirement('At least 1 special character', _hasSpecialChar),
                  ],
                ),
              ),
              
              Text(
                'DELIVERY ADDRESS',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: subtitleColor, letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              GooglePlaceAutoCompleteTextField(
                textEditingController: _addressController,
                googleAPIKey: AppConstants.googleMapsApiKey,
                inputDecoration: InputDecoration(
                  hintText: 'Start typing your address...',
                  hintStyle: TextStyle(color: subtitleColor, fontSize: 13, fontWeight: FontWeight.w300),
                  filled: true,
                  fillColor: inputBgColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: inputBorderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: inputBorderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor),
                  ),
                ),
                debounceTime: 800,
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
                  _addressController.selection = TextSelection.fromPosition(TextPosition(offset: prediction.description?.length ?? 0));
                },
                itemBuilder: (context, index, Prediction prediction) {
                  return Container(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Icon(Icons.location_on, color: primaryColor),
                        const SizedBox(width: 7),
                        Expanded(child: Text(prediction.description ?? "", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300)))
                      ],
                    ),
                  );
                },
                seperatedBuilder: const Divider(),
              ),

              const SizedBox(height: 16),
              const Text(
                'OR PIN ON MAP',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.grey, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 180,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(target: _selectedLocation, zoom: 15),
                    onMapCreated: (controller) {
                      _mapController = controller;
                      _mapController?.setMapStyle(_mapStyle);
                    },
                    markers: _markers,
                    onTap: (LatLng position) {
                      _updateMarker(position);
                      _getAddressFromLatLng(position);
                    },
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: false,
                  ),
                ),
              ),

              const SizedBox(height: 20),
              _buildTextField('ADDITIONAL ADDRESS DETAILS', 'Apt, Suite, Floor, etc.', _additionalAddressController, maxLines: 2),

              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: _agreedToTerms,
                    onChanged: (val) => setState(() => _agreedToTerms = val ?? false),
                    activeColor: primaryColor,
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
                                style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
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
                                style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_isLoading || !(_has8Chars && _hasNumber && _hasSpecialChar)) ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Register & Continue', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
