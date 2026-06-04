import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
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
  // Use the generic YOLO class for single-image tasks if needed
  late YOLO yolo;
  bool _isProcessingSelection = false;
  dynamic _topResult;

  @override
  void initState() {
    super.initState();
    // Initialize the YOLO object for background tasks
    yolo = YOLO(modelPath: 'assets/models/best_float32.tflite');
  }

  void _handleDetection(List<dynamic> results) {
    if (_isProcessingSelection || results.isEmpty) return;

    // Classification results follow this format: {name: String, confidence: Double}
    final result = results.first;
    
    setState(() {
      _topResult = result;
    });

    final String topLabel = result.className ?? '';
    final double confidence = result.confidence ?? 0.0;

<<<<<<< Updated upstream
    if (confidence > 0.50) {
=======
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
>>>>>>> Stashed changes
      try {
        final searchLabel = topLabel.toLowerCase().trim();
        final matchedItem = widget.controller.allItems.firstWhere(
          (item) => item.name.toLowerCase().contains(searchLabel) || 
                    item.category.toLowerCase().contains(searchLabel),
        );

        _isProcessingSelection = true;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Recognized: ${matchedItem.name}"),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 1),
          )
        );

        widget.onSelectItem(matchedItem);
        
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _isProcessingSelection = false);
        });
      } catch (_) {
        // Item not found in database
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(title: const Text("AI Visual Search")),
      body: Stack(
        children: [
          // YOLOView requires modelPath directly in v0.3.3+
          YOLOView(
            modelPath: 'assets/models/best_float32.tflite',
            onResult: _handleDetection,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildResultOverlay(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultOverlay() {
    if (_topResult == null) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 40.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Text(
          "${_topResult.className} (${(_topResult.confidence * 100).round()}%)",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}