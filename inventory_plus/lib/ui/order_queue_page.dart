import 'package:flutter/material.dart';
import '../data/inventory.dart';
import '../logic/inventory_controller.dart';
import 'item_detail_page.dart';
import 'scanner_search_page.dart';
import 'store_map.dart'; // Added import for the map view

class OrderQueuePage extends StatefulWidget {
  final InventoryController controller;

  const OrderQueuePage({super.key, required this.controller});

  @override
  State<OrderQueuePage> createState() => _OrderQueuePageState();
}

class _OrderQueuePageState extends State<OrderQueuePage> {
  // Helper to format "time ago"
  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _navigateToOrderChecklist(dynamic order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderChecklistPage(
          order: order,
          controller: widget.controller,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F0), // Light cream background
      appBar: AppBar(
        title: const Text('Helper Dashboard', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        
      ),
      body: StreamBuilder<List<dynamic>>( // Assuming CustomerOrder type
        stream: widget.controller.streamOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFF58220)));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          final orders = snapshot.data ?? [];
          final pendingOrders = orders.where((o) => o.status == 'pending').toList();

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // TOP STATS ROW (Removed Dwell Time)
                _buildStatCard("ACTIVE QUEUE", "${pendingOrders.length}", const Color(0xFFD67E24)),
                const SizedBox(height: 16),

                // ORDER LIST
                Expanded(
                  child: pendingOrders.isEmpty
                      ? const Center(
                          child: Text(
                            'No pending orders right now!',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: pendingOrders.length,
                          itemBuilder: (context, index) {
                            final order = pendingOrders[index];
                            final String shortId = order.id.toString().substring(0, 8).toUpperCase();
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: index == 0 ? const Color(0xFFF58220) : Colors.grey.shade300,
                                  width: index == 0 ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '#ORD-$shortId',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                                          ),
                                          if (index == 0) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF9E651D),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text('URGENT', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                            ),
                                          ]
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.inventory_2_outlined, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text('${order.items.length} items', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                          const SizedBox(width: 12),
                                          const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(_timeAgo(order.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  ElevatedButton(
                                    onPressed: () => _navigateToOrderChecklist(order),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFF58220),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    ),
                                    child: const Text('Prepare', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBEADB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF3E322C))),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }
}

// ============================================================================
// FULL SCREEN CHECKLIST PAGE
// ============================================================================

class OrderChecklistPage extends StatefulWidget {
  final dynamic order; 
  final InventoryController controller;

  const OrderChecklistPage({
    super.key,
    required this.order,
    required this.controller,
  });

  @override
  State<OrderChecklistPage> createState() => _OrderChecklistPageState();
}

class _OrderChecklistPageState extends State<OrderChecklistPage> {
  final Map<String, bool> _checkedItems = {};

  @override
  void initState() {
    super.initState();
    for (var item in widget.order.items) {
      _checkedItems[item.productId] = false;
    }
  }

  bool get _allChecked => _checkedItems.values.every((v) => v);
  int get _checkedCount => _checkedItems.values.where((v) => v).length;
  int get _totalCount => widget.order.items.length;

  void _markPrepared() async {
    await widget.controller.updateOrderStatus(widget.order.id, 'prepared');
    if (mounted) {
      Navigator.pop(context); // Go back to queue
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order marked as Prepared!'), backgroundColor: Colors.green),
      );
    }
  }

  // UPDATED: Now opens the StoreMap view directly instead of the full ItemDetailPage
  void _showItemLocationOnMap(String productId) {
    try {
      final item = widget.controller.allItems.firstWhere((i) => i.id == productId);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text('Location: ${item.name}'),
              backgroundColor: Colors.white,
              iconTheme: const IconThemeData(color: Colors.black87),
              titleTextStyle: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            body: StoreMap(
              controller: widget.controller,
              highlightId: item.locationId, 
              itemName: item.name,
              mode: MapMode.view,
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item location details not found.')),
      );
    }
  }

  // SHOW DEDUCTION MODAL
  // SHOW DEDUCTION MODAL
  void _showDeductionSheet(InventoryItem dbItem, int targetQuantity) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DeductionBottomSheet(
        item: dbItem,
        targetQuantity: targetQuantity,
        onConfirm: (deductedQty) async {
          
          // ==========================================================
          // 🐛 FIX: LIVE DATABASE DEDUCTION REMOVED HERE
          // ==========================================================
          // We deleted `widget.controller.updateItem()` so the Helper 
          // no longer deducts stock. The Cashier will deduct the stock 
          // when they click "Complete" on their end.
          
          // Just mark the item as checked off on the Helper's UI
          if (mounted) {
            setState(() {
              _checkedItems[dbItem.id] = true;
            });
            Navigator.pop(context); // Close bottom sheet
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${dbItem.name} checked off!'), backgroundColor: Colors.green),
            );
          }
        },
      ),
    );
  }
  void _openScannerToCheckoff() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScannerSearchPage(
          controller: widget.controller,
          onSelectItem: (scannedItem) {
            Navigator.pop(context); // Close the scanner view
            if (_checkedItems.containsKey(scannedItem.id)) {
              // Find the quantity required for this specific order
              final orderItem = widget.order.items.firstWhere((i) => i.productId == scannedItem.id);
              _showDeductionSheet(scannedItem, orderItem.quantity);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${scannedItem.name} is not in this order!'), backgroundColor: Colors.red),
              );
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String shortId = widget.order.id.toString().substring(0, 8).toUpperCase();
    final double progress = _totalCount == 0 ? 0 : _checkedCount / _totalCount;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F0), 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          // HEADER SECTION
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("ORDER ASSIGNMENT", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        const SizedBox(height: 4),
                        Text("ID: #ORD-$shortId", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBEADB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text("$_checkedCount/$_totalCount", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF9E651D))),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: const Color(0xFFFBEADB),
                  color: const Color(0xFFF58220),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(10),
                ),
                const SizedBox(height: 8),
                const Text("READY FOR PICKING • ZONE B", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              ],
            ),
          ),
          
          const SizedBox(height: 20),

          // FULL WIDTH SCAN BUTTON
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _openScannerToCheckoff,
                icon: const Icon(Icons.camera_alt, size: 18),
                label: const Text("Scan to Checkoff", style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3E322C), 
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),

          // CHECKLIST ITEMS
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: widget.order.items.length,
              itemBuilder: (context, index) {
                final item = widget.order.items[index];
                final bool isChecked = _checkedItems[item.productId] ?? false;

                return GestureDetector(
                  onTap: () {
                    if (!isChecked) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please scan the item\'s QR code to check it off.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      _openScannerToCheckoff();
                    } else {
                      // Uncheck manually
                      setState(() {
                        _checkedItems[item.productId] = false;
                      });
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isChecked ? const Color(0xFFE8F5E9) : Colors.white,
                      border: Border.all(
                        color: isChecked ? const Color(0xFFC8E6C9) : const Color(0xFFFBEADB),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        // Checkbox UI
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isChecked ? const Color(0xFFF58220) : Colors.white,
                            border: Border.all(color: isChecked ? const Color(0xFFF58220) : Colors.grey.shade400, width: 2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: isChecked ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                        ),
                        const SizedBox(width: 16),
                        
                        // Item Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.black87,
                                  decoration: isChecked ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isChecked ? const Color(0xFF81C784) : const Color(0xFFFBEADB),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'QTY: ${item.quantity.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isChecked ? Colors.white : const Color(0xFF9E651D),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text("AISLE 12 • BIN A", style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        // Location Pin Action
                        IconButton(
                          icon: const Icon(Icons.map_outlined, color: Colors.black54),
                          onPressed: () => _showItemLocationOnMap(item.productId),
                          tooltip: 'View Location Map',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // BOTTOM NOTIFY BUTTON
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8E9DE),
              border: Border(top: BorderSide(color: Colors.orange.withOpacity(0.2))),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _allChecked ? _markPrepared : null,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text("NOTIFY CASHIER (PREPARED)", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCEB8A6), 
                  disabledBackgroundColor: const Color(0xFFE2D4C8),
                  disabledForegroundColor: Colors.white70,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ).copyWith(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.disabled)) return const Color(0xFFDAC7B8);
                    return const Color(0xFFF58220); 
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// NEW: DEDUCTION BOTTOM SHEET MODAL
// ============================================================================

class DeductionBottomSheet extends StatefulWidget {
  final InventoryItem item;
  final int targetQuantity;
  final Function(int) onConfirm;

  const DeductionBottomSheet({
    super.key,
    required this.item,
    required this.targetQuantity,
    required this.onConfirm,
  });

  @override
  State<DeductionBottomSheet> createState() => _DeductionBottomSheetState();
}

class _DeductionBottomSheetState extends State<DeductionBottomSheet> {
  late TextEditingController _qtyController;
  late int _currentQty;

  @override
  void initState() {
    super.initState();
    _currentQty = widget.targetQuantity;
    _qtyController = TextEditingController(text: _currentQty.toString());
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  void _updateQuantity(int newQty) {
    if (newQty < 1) newQty = 1;
    if (newQty > widget.item.quantity) newQty = widget.item.quantity; // Max available
    setState(() {
      _currentQty = newQty;
      _qtyController.text = newQty.toString();
    });
  }

  void _submitManualEntry() {
    final val = int.tryParse(_qtyController.text);
    if (val != null) {
      _updateQuantity(val);
    } else {
      _qtyController.text = _currentQty.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final int remainingStock = widget.item.quantity - _currentQty;
    final String locationString = (widget.item.shelfLevel != null || widget.item.binNumber != null)
        ? "${widget.item.shelfLevel ?? ''} ${widget.item.binNumber ?? ''}".trim()
        : "Unassigned";

    return Padding(
      // Padding added for keyboard avoidance
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. TOP SCANNED ITEM CARD
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Image with Badge
                  Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: NetworkImage(widget.item.imageUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: const BoxDecoration(
                            color: Colors.greenAccent,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                          child: const Text(
                            "SCANNED",
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "SKU-${widget.item.sku}",
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.item.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.inventory_2, size: 14, color: Colors.green),
                            const SizedBox(width: 4),
                            Text(
                              "${widget.item.quantity} units available",
                              style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. MIDDLE QUANTITY CARD (Beige)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFBEADB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Text(
                    "HOW MANY UNITS TO REMOVE?",
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Color(0xFF3E322C)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Minus Button
                      InkWell(
                        onTap: () => _updateQuantity(_currentQty - 1),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3E322C),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.remove, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Text Field
                      SizedBox(
                        width: 60,
                        child: Focus(
                          onFocusChange: (hasFocus) {
                            if (!hasFocus) _submitManualEntry();
                          },
                          child: TextField(
                            controller: _qtyController,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            onSubmitted: (_) => _submitManualEntry(),
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                            decoration: const InputDecoration(
                              isDense: true,
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.orange, width: 2)),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.orange, width: 2)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Plus Button
                      InkWell(
                        onTap: () => _updateQuantity(_currentQty + 1),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3E322C),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Manual entry supported",
                    style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. LIGHT BLUE INFO BOX
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.lightBlue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.lightBlue.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.lightBlue.shade700, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "After deduction, $remainingStock units will remain at shelf Location $locationString.",
                      style: TextStyle(color: Colors.blueGrey.shade800, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. CONFIRM BUTTON
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () => widget.onConfirm(_currentQty),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text(
                  "Confirm Deduction",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF58220),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}