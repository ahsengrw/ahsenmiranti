import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:signature/signature.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/order.dart';
import '../../services/api_service.dart';
import '../../core/constants.dart';

class ProofOfDeliveryScreen extends StatefulWidget {
  final Order order;
  const ProofOfDeliveryScreen({Key? key, required this.order}) : super(key: key);

  @override
  State<ProofOfDeliveryScreen> createState() => _ProofOfDeliveryScreenState();
}

class _ProofOfDeliveryScreenState extends State<ProofOfDeliveryScreen> {
  CameraController? _cameraController;
  Future<void>? _initializeControllerFuture;
  XFile? _capturedImage;
  bool _isSignatureStep = false;
  bool _isUploading = false;

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    _cameraController = CameraController(cameras.first, ResolutionPreset.medium, enableAudio: false);
    _initializeControllerFuture = _cameraController!.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    try {
      await _initializeControllerFuture;
      final image = await _cameraController!.takePicture();
      setState(() {
        _capturedImage = image;
        _isSignatureStep = true;
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _completeOrder() async {
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide a signature')));
      return;
    }

    setState(() => _isUploading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = jsonDecode(prefs.getString(AppConstants.keyUserData) ?? '{}');
      
      // Convert captured image to Base64
      String? base64Proof;
      if (_capturedImage != null) {
        final bytes = await File(_capturedImage!.path).readAsBytes();
        base64Proof = "data:image/jpeg;base64,${base64.encode(bytes)}";
      }

      // Convert signature to Base64
      final signatureBytes = await _signatureController.toPngBytes();
      String? base64Signature;
      if (signatureBytes != null) {
        base64Signature = "data:image/png;base64,${base64.encode(signatureBytes)}";
      }

      await ApiService.put('orders', {
        'order_id': widget.order.id,
        'status': 'delivered',
        'driver_id': userData['id'],
        'delivery_proof': base64Proof,
        'customer_signature': base64Signature
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order completed successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to complete order')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSignatureStep) {
      return _buildSignatureView();
    }
    return _buildCameraView();
  }

  Widget _buildCameraView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return Center(
                  child: AspectRatio(
                    aspectRatio: _cameraController!.value.aspectRatio,
                    child: CameraPreview(_cameraController!),
                  ),
                );
              } else {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }
            },
          ),
          Center(
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                children: [
                   _buildCornerFixed(left: 0, top: 0, isTop: true, isLeft: true),
                   _buildCornerFixed(right: 0, top: 0, isTop: true, isLeft: false),
                   _buildCornerFixed(left: 0, bottom: 0, isTop: false, isLeft: true),
                   _buildCornerFixed(right: 0, bottom: 0, isTop: false, isLeft: false),
                   const Center(child: Icon(Icons.inventory_2, color: Colors.white30, size: 80)),
                ],
              ),
            ),
          ),
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Center(
                    child: Text('Take Photo Proof', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _takePicture,
                child: Container(
                  width: 80,
                  height: 80,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
                  child: Container(decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCornerFixed({double? left, double? top, double? right, double? bottom, required bool isTop, required bool isLeft}) {
    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border(
            top: isTop ? const BorderSide(color: Color(0xFF10B981), width: 6) : BorderSide.none,
            bottom: !isTop ? const BorderSide(color: Color(0xFF10B981), width: 6) : BorderSide.none,
            left: isLeft ? const BorderSide(color: Color(0xFF10B981), width: 6) : BorderSide.none,
            right: !isLeft ? const BorderSide(color: Color(0xFF10B981), width: 6) : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildSignatureView() {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Customer Signature', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () => setState(() => _isSignatureStep = false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white, fontSize: 16)),
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            color: const Color(0xFFFFFBEB),
            child: Row(
              children: [
                const Icon(Icons.money_rounded, color: Color(0xFFD97706), size: 32),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('COLLECT PAYMENT', style: TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.bold, fontSize: 12)),
                    Text('\$${widget.order.totalAmount.toStringAsFixed(2)} Cash', style: const TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      Signature(
                        controller: _signatureController,
                        backgroundColor: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _signatureController.clear(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      foregroundColor: const Color(0xFF475569),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _completeOrder,
                    icon: _isUploading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check, size: 20),
                    label: const Text('Complete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
