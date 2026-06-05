import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:inventory_plus/ui/widgets/item_card.dart';
import '../logic/inventory_controller.dart';
import '../data/inventory.dart';

class VisualSearchPage extends StatefulWidget {
  final InventoryController controller;
  final Function(InventoryItem) onSelectItem;

  const VisualSearchPage({
    super.key,
    required this.controller,
    required this.onSelectItem,
  });

  @override
  State<VisualSearchPage> createState() => _VisualSearchPageState();
}

class _VisualSearchPageState extends State<VisualSearchPage> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;

  bool _isProcessing = false;
  bool _isLiveMode = false;
  Timer? _liveScanTimer;
  InventoryItem? _scannedItem;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        _cameraController = CameraController(
          _cameras[_currentCameraIndex],
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint("Camera initialization error: $e");
    }
  }

  void _flipCamera() async {
    if (_cameras.length < 2) return;

    final wasLive = _isLiveMode;
    if (wasLive) _toggleLiveMode();

    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    await _initializeCamera();

    if (wasLive) _toggleLiveMode();
  }

  void _toggleLiveMode() {
    setState(() {
      _isLiveMode = !_isLiveMode;
    });

    if (_isLiveMode) {
      _captureAndAnalyze();
      _liveScanTimer = Timer.periodic(const Duration(milliseconds: 1500), (
        timer,
      ) {
        if (!_isProcessing && _scannedItem == null && mounted) {
          _captureAndAnalyze();
        }
      });
    } else {
      _liveScanTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _liveScanTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

 // --- THE FINAL NETWORK BRIDGE ---
  Future<void> _captureAndAnalyze() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    // In live mode, if we are already processing a frame, just skip this timer tick
    if (_isLiveMode && _isProcessing) return;

    if (mounted) {
      setState(() => _isProcessing = true);
    }

    try {
      final XFile imageFile = await _cameraController!.takePicture();
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://127.0.0.1:8000/analyze-frame'),
      );
      final imageBytes = await imageFile.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes('image', imageBytes, filename: 'scan.jpg'),
      );

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      Map<String, dynamic>? data;
      try {
        data = jsonDecode(responseData);
      } catch (e) {
        debugPrint("JSON Decode Error: $e");
        return;
      }

      if (data != null && data['status'] == 'success') {
        final searchLabel = data['item'].toString().toLowerCase().trim();
        debugPrint("AI FOUND: $searchLabel");

        try {
          // A MORE FORGIVING SEARCH: Look for partial matches in both name and category
          final matchedItem = widget.controller.allItems.firstWhere((item) {
            final itemName = item.name.toLowerCase();
            final itemCat = item.category.toLowerCase();
            return itemName.contains(searchLabel) ||
                itemCat.contains(searchLabel) ||
                searchLabel.contains(
                  itemName,
                ) || // E.g., if AI says "claw hammer" and DB has "hammer"
                searchLabel.contains(itemCat);
          });

          if (mounted) {
            setState(() {
              _scannedItem = matchedItem;
              _isProcessing = false;
            });

            // STOP LIVE MODE IMMEDIATELY UPON SUCCESS
            if (_isLiveMode) {
              _toggleLiveMode();
            }
          }
        } catch (_) {
          debugPrint("ITEM NOT FOUND IN DATABASE");

          if (mounted) {
            // STOP LIVE MODE EVEN IF ITEM IS MISSING
            if (_isLiveMode) {
              _toggleLiveMode();
            }

            // Force the UI to stop spinning and show the error
            setState(() {
              _isProcessing = false;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "AI recognized '$searchLabel', but it is not in your inventory database.",
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        if (mounted && !_isLiveMode) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("No tools recognized. Try pointing closer."),
              duration: Duration(milliseconds: 800),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Network Error: $e");
    } finally {
      if (mounted && _scannedItem == null && !_isLiveMode) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _resetScanner() {
    setState(() => _scannedItem = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text(
          "AI Object Scanner",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              _isLiveMode ? Icons.videocam : Icons.camera_alt,
              color: _isLiveMode ? Colors.greenAccent : Colors.white,
            ),
            tooltip: "Toggle Live Mode",
            onPressed: _scannedItem == null ? _toggleLiveMode : null,
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch, color: Colors.white),
            tooltip: "Flip Camera",
            onPressed: _scannedItem == null ? _flipCamera : null,
          ),
          const SizedBox(width: 8),
        ],
      ),
      backgroundColor: Colors.black,
      body: _scannedItem != null
          ? _buildScannedResultView()
          : _buildCameraView(),
    );
  }

  Widget _buildCameraView() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      );
    }

    return Stack(
      children: [
        Positioned.fill(child: CameraPreview(_cameraController!)),
        Positioned.fill(child: CustomPaint(painter: ScannerOverlayPainter())),

        Positioned(
          top: 20,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: _isLiveMode
                    ? Colors.green.withOpacity(0.8)
                    : Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _isLiveMode ? "LIVE MODE ACTIVE" : "CAPTURE MODE",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),

        Positioned(
          bottom: 110,
          left: 0,
          right: 0,
          child: Column(
            children: [
              const Text(
                "Align object within the frame",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Scanning for wrenches, hammers, and screwdrivers",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                  shadows: const [Shadow(blurRadius: 10, color: Colors.black)],
                ),
              ),
            ],
          ),
        ),

        Positioned(
          bottom: 30,
          left: 0,
          right: 0,
          child: Center(
            child: _isLiveMode
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.orange,
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        "Scanning background...",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                : ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _captureAndAnalyze,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.document_scanner),
                    label: Text(
                      _isProcessing ? "Analyzing Image..." : "Scan Object",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildScannedResultView() {
    return Container(
      color: Colors.grey[50],
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  CircleAvatar(radius: 4, backgroundColor: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    "Object Recognized",
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: _resetScanner,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.orange[50],
                  shape: const StadiumBorder(),
                ),
                child: const Text(
                  "Scan Another",
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ItemCard(item: _scannedItem!, onClick: widget.onSelectItem),
        ],
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = Colors.black54;
    final clearPaint = Paint()
      ..color = Colors.transparent
      ..blendMode = BlendMode.clear;
    final borderPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.saveLayer(rect, Paint());
    canvas.drawRect(rect, backgroundPaint);

    final double boxSize = size.width * 0.60;
    final double left = (size.width - boxSize) / 2;
    final double top = (size.height - boxSize) / 2;
    final boxRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, boxSize, boxSize),
      const Radius.circular(16),
    );

    canvas.drawRRect(boxRect, clearPaint);

    const double cornerLength = 30;
    canvas.drawLine(
      Offset(left, top),
      Offset(left + cornerLength, top),
      borderPaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left, top + cornerLength),
      borderPaint,
    );
    canvas.drawLine(
      Offset(left + boxSize, top),
      Offset(left + boxSize - cornerLength, top),
      borderPaint,
    );
    canvas.drawLine(
      Offset(left + boxSize, top),
      Offset(left + boxSize, top + cornerLength),
      borderPaint,
    );
    canvas.drawLine(
      Offset(left, top + boxSize),
      Offset(left + cornerLength, top + boxSize),
      borderPaint,
    );
    canvas.drawLine(
      Offset(left, top + boxSize),
      Offset(left, top + boxSize - cornerLength),
      borderPaint,
    );
    canvas.drawLine(
      Offset(left + boxSize, top + boxSize),
      Offset(left + boxSize - cornerLength, top + boxSize),
      borderPaint,
    );
    canvas.drawLine(
      Offset(left + boxSize, top + boxSize),
      Offset(left + boxSize, top + boxSize - cornerLength),
      borderPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
