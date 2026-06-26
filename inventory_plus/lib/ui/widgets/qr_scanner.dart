import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScanner extends StatefulWidget {
  final Function(String) onScan;
  final bool isScanning;

  const QRScanner({
    super.key,
    required this.onScan,
    required this.isScanning,
  });

  @override
  State<QRScanner> createState() => _QRScannerState();
}

class _QRScannerState extends State<QRScanner> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _hasScanned = false; 
  bool _isTorchOn = false;
  final MobileScannerController _cameraController = MobileScannerController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);

    if (widget.isScanning) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(QRScanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScanning && !oldWidget.isScanning) {
      _hasScanned = false; 
      _controller.repeat(reverse: true);
    } else if (!widget.isScanning) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
  controller: _cameraController,
  fit: BoxFit.cover,
  onDetect: (capture) {
    if (_hasScanned || !widget.isScanning) return;
 
    final Size widgetSize = MediaQuery.of(context).size;
    if (widgetSize.isEmpty) return;
 
    // The size of the raw image from the camera
    final Size imageSize = capture.size;
 
    // The on-screen size of the scan window
    const double scanBoxSize = 250;
    final Rect scanWindow = Rect.fromCenter(
      center: Offset(widgetSize.width / 2, widgetSize.height / 2),
      width: scanBoxSize,
      height: scanBoxSize,
    );
 
    for (final barcode in capture.barcodes) {
  // Use corners instead of boundingBox
  final corners = barcode.corners;
  
  if (corners.isNotEmpty) {
    // Calculate the bounding box from the corners
    final double minX = corners.map((c) => c.dx).reduce((a, b) => a < b ? a : b);
    final double minY = corners.map((c) => c.dy).reduce((a, b) => a < b ? a : b);
    final double maxX = corners.map((c) => c.dx).reduce((a, b) => a > b ? a : b);
    final double maxY = corners.map((c) => c.dy).reduce((a, b) => a > b ? a : b);
    
    final Rect barcodeBox = Rect.fromLTRB(minX, minY, maxX, maxY);

    // Transform to widget coordinates
    final Rect transformedBoundingBox = _transformBoundingBox(
      barcodeBox,
      imageSize,
      widgetSize,
    );

    // Check if the barcode center is within the scan window
    if (scanWindow.contains(transformedBoundingBox.center)) {
      _hasScanned = true;
      if (barcode.rawValue != null) widget.onScan(barcode.rawValue!);
      break;
    }
  } else if (barcode.rawValue != null) {
    // Fallback if corners are unavailable
    _hasScanned = true;
    widget.onScan(barcode.rawValue!);
    break;
  }
}
  },
),
          _buildScannerOverlay(),

          _buildDecorativeElements(),

          // NEW: Flashlight Toggle Button
          // FIXED: Flashlight Toggle Button
Positioned(
  bottom: 30,
  right: 30,
  child: FloatingActionButton(
    heroTag: 'flashlight_button',
    onPressed: () {
      _cameraController.toggleTorch();
      setState(() => _isTorchOn = !_isTorchOn);
    },
    backgroundColor: _isTorchOn ? Colors.orange : Colors.grey[800],
    child: Stack(
      alignment: Alignment.center,
      children: [
        if (_isTorchOn)
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.7),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),
        Icon(
          _isTorchOn ? Icons.flashlight_on : Icons.flashlight_off,
          color: Colors.white,
        ),
      ],
    ),
  ),
),
        ],
      ),
    );
  }

  // Helper to convert barcode bounding box from image coordinates to widget coordinates
  Rect _transformBoundingBox(Rect box, Size imageSize, Size widgetSize) {
    // This function handles the conversion from the camera's image coordinate system
    // to the Flutter widget's coordinate system, accounting for `BoxFit.cover`.

    final double scaleX = widgetSize.width / imageSize.width;
    final double scaleY = widgetSize.height / imageSize.height;
    final double scale = scaleX > scaleY ? scaleX : scaleY;

    final double newWidth = imageSize.width * scale;
    final double newHeight = imageSize.height * scale;

    final double offsetX = (widgetSize.width - newWidth) / 2;
    final double offsetY = (widgetSize.height - newHeight) / 2;

    return Rect.fromLTRB(
      box.left * scale + offsetX,
      box.top * scale + offsetY,
      box.right * scale + offsetX,
      box.bottom * scale + offsetY,
    );
  }

  Widget _buildScannerOverlay() {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.black.withOpacity(0.5),
        BlendMode.srcOut,
      ),
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              backgroundBlendMode: BlendMode.dstOut,
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              height: 250,
              width: 250,
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecorativeElements() {
    return Center(
      child: SizedBox(
        width: 250,
        height: 250,
        child: Stack(
          children: [
            _buildCorner(top: 0, left: 0, isTop: true, isLeft: true),
            _buildCorner(top: 0, right: 0, isTop: true, isLeft: false),
            _buildCorner(bottom: 0, left: 0, isTop: false, isLeft: true),
            _buildCorner(bottom: 0, right: 0, isTop: false, isLeft: false),
            
            if (widget.isScanning)
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Positioned(
                    top: _animation.value * 250,
                    left: 0,
                    right: 0,
                    child: _buildLaserLine(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLaserLine() {
    return Container(
      height: 2,
      decoration: BoxDecoration(
        color: Colors.orange,
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.6),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildCorner({double? top, double? bottom, double? left, double? right, required bool isTop, required bool isLeft}) {
    return Positioned(
      top: top, bottom: bottom, left: left, right: right,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          border: Border(
            top: isTop ? const BorderSide(color: Colors.orange, width: 4) : BorderSide.none,
            bottom: !isTop ? const BorderSide(color: Colors.orange, width: 4) : BorderSide.none,
            left: isLeft ? const BorderSide(color: Colors.orange, width: 4) : BorderSide.none,
            right: !isLeft ? const BorderSide(color: Colors.orange, width: 4) : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: isTop && isLeft ? const Radius.circular(8) : Radius.zero,
            topRight: isTop && !isLeft ? const Radius.circular(8) : Radius.zero,
            bottomLeft: !isTop && isLeft ? const Radius.circular(8) : Radius.zero,
            bottomRight: !isTop && !isLeft ? const Radius.circular(8) : Radius.zero,
          ),
        ),
      ),
    );
  }
}