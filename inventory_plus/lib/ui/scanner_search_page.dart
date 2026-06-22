import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:inventory_plus/ui/widgets/qr_scanner.dart';
import 'package:inventory_plus/ui/widgets/item_card.dart';
import '../data/inventory.dart'; 
import '../logic/inventory_controller.dart';
import 'package:inventory_plus/ui/visual_search_page.dart';

class ScannerSearchPage extends StatefulWidget {
  final InventoryController controller; 
  final Function(InventoryItem) onSelectItem;

  const ScannerSearchPage({
    super.key,
    required this.controller,
    required this.onSelectItem,
  });

  @override
  State<ScannerSearchPage> createState() => _ScannerSearchPageState();
}

class _ScannerSearchPageState extends State<ScannerSearchPage> {
  bool _isScanning = true;
  InventoryItem? _scannedItem;

  bool get _canUseAI {
    final role = widget.controller.currentUserRole?.toLowerCase() ?? 'staff';
    return role == 'admin' || role == 'staff';
  }

  void _handleRealScan(String scannedValue) {
    if (!_isScanning) return;
    setState(() => _isScanning = false);

    InventoryItem? foundItem;
    try {
      final cleanValue = scannedValue.trim();

      foundItem = widget.controller.allItems.firstWhere(
        (item) => item.sku == cleanValue || item.id == cleanValue,
      );
    } catch (_) {
      foundItem = null; // firstWhere throws an error if no match is found
    }

    if (foundItem != null) {
      setState(() => _scannedItem = foundItem);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Code: $scannedValue not found"),
          backgroundColor: Colors.redAccent,
        ),
      );
      _resetScanner();
    }
  }

  void _resetScanner() {
    setState(() {
      _scannedItem = null;
      _isScanning = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _scannedItem == null
                  ? QRScanner(
                      onScan: _handleRealScan,
                      isScanning: _isScanning,
                    )
                  : Container(
                      color: Colors.grey[50],
                      padding: const EdgeInsets.only(top: 140, left: 16, right: 16),
                      child: _buildScannedResultView(),
                    ),
            ),
          ),

          Positioned(
            top: 0, left: 0, right: 0,
            child: _buildHeader(),
          ),
          
          if (_scannedItem == null)
            _buildScannerInstructions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 40, bottom: 20, left: 16, right: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0F172A),
            const Color(0xFF0F172A).withOpacity(0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // UPDATED: Placed the Title and the new Object Scanner Button in a Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.chevronLeft, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    "Hardware Inventory",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (_canUseAI)
                ElevatedButton.icon(
                  onPressed: () {
                    // This opens your new Object Scanner
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VisualSearchPage(
                          controller: widget.controller,
                          onSelectItem: widget.onSelectItem,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    LucideIcons.scanLine,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: const Text(
                    "AI Scanner",
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScannedResultView() {
    return Column(
      key: const ValueKey("result"),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                CircleAvatar(radius: 4, backgroundColor: Colors.green),
                SizedBox(width: 8),
                Text("Item Found", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
            TextButton(
              onPressed: _resetScanner,
              style: TextButton.styleFrom(backgroundColor: Colors.orange[50], shape: const StadiumBorder()),
              child: const Text("Scan Another", style: TextStyle(color: Colors.orange, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ItemCard(item: _scannedItem!, onClick: widget.onSelectItem),
        const SizedBox(height: 16),
        _buildQuickActionNotice(),
      ],
    );
  }

  Widget _buildQuickActionNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Quick Action", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text(
            "Tap the card above to view full details or update inventory.",
            style: TextStyle(color: Colors.blue, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerInstructions() {
    return Positioned(
      bottom: 40, left: 0, right: 0,
      child: Column(
        children: [
          const Text(
            "Scan Barcode or QR",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 10)]),
          ),
          const SizedBox(height: 4),
          Text(
            "Align the code within the frame",
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, shadows: const [Shadow(blurRadius: 10)]),
          ),
        ],
      ),
    );
  }
}