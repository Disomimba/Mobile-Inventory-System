import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../data/inventory.dart';
import '../logic/inventory_controller.dart';
import 'visual_search_page.dart';

// ─── Snap positions as fractions of total screen height ──────────────────────
const double _kSnapFull = 0.75;

// FIX 1: Increased from 140 to 165 to account for actual chrome height:
// drag handle (~24px) + orange header (~56px) + footer (~80px) + buffer = ~165px
const double _kChromeOnlyHeightPx = 165.0;

class PosCartPage extends StatefulWidget {
  final InventoryController controller;

  const PosCartPage({super.key, required this.controller});

  @override
  State<PosCartPage> createState() => _PosCartPageState();
}

class _PosCartPageState extends State<PosCartPage>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  final Map<String, double> _cart = {};
  bool? _isGridView;
  bool _isProcessingCart = false;

  // ── Draggable panel state ──────────────────────────────────────────────────
  double _cartHeightFraction = 0.0;
  late AnimationController _snapAnim;
  late Animation<double> _snapAnimation;
  double _dragStart = 0;
  double _fractionAtDragStart = 0;

  @override
  void initState() {
    super.initState();
    _snapAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final mq = MediaQuery.of(context);
      final totalHeight = mq.size.height - mq.padding.top;
      if (totalHeight <= 0) return;
      setState(() {
        _cartHeightFraction = (_kChromeOnlyHeightPx / totalHeight).clamp(
          0.0,
          _kSnapFull,
        );
      });
    });
  }

  @override
  void dispose() {
    _snapAnim.dispose();
    super.dispose();
  }

  void _snapTo(double target) {
    final start = _cartHeightFraction;
    // Use a spring simulation for natural deceleration — no magnetic snap feel.
    // ElasticOut would overshoot; FastLinearToSlowEaseIn front-loads motion
    // so the sheet arrives gently rather than snapping into place.
    _snapAnimation =
        Tween<double>(begin: start, end: target).animate(
          CurvedAnimation(
            parent: _snapAnim,
            curve: const Cubic(
              0.25,
              0.46,
              0.45,
              0.94,
            ), // ease-out-quad: smooth & natural
          ),
        )..addListener(() {
          setState(() => _cartHeightFraction = _snapAnimation.value);
        });
    _snapAnim
      ..reset()
      ..forward();
  }

  void _onDragEnd(DragEndDetails details) {
    final mq = MediaQuery.of(context);
    final safeHeight = mq.size.height - mq.padding.top - mq.padding.bottom - 56;
    final totalHeight = mq.size.height - mq.padding.top;
    if (totalHeight <= 0) return;

    final floorFraction = (_kChromeOnlyHeightPx / totalHeight).clamp(
      0.0,
      _kSnapFull,
    );
    final safeMax = (safeHeight / totalHeight).clamp(floorFraction, _kSnapFull);

    final velocity = details.primaryVelocity ?? 0;
    double target;

    if (velocity < -800) {
      target = safeMax;
    } else if (velocity > 800) {
      target = floorFraction;
    } else {
      target =
          (_cartHeightFraction - floorFraction).abs() <
              (_cartHeightFraction - safeMax).abs()
          ? floorFraction
          : safeMax;
    }
    _snapTo(target.clamp(floorFraction, safeMax));
  }

  // ── Cart logic ─────────────────────────────────────────────────────────────
  List<InventoryItem> get _filteredItems =>
      widget.controller.searchInventory(_searchQuery);

  bool _addToCart(InventoryItem item) {
    if (_isProcessingCart) return false;
    final currentQty = _cart[item.id] ?? 0;
    if (currentQty >= item.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot add more of ${item.name}. Stock limit reached.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }
    setState(() => _cart[item.id] = currentQty + 1);
    return true;
  }

  void _setCartQuantity(String itemId, double qty) {
    if (_isProcessingCart) return;
    try {
      final item = widget.controller.allItems.firstWhere((i) => i.id == itemId);
      if (qty > item.quantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot set quantity to $qty. Only ${item.quantity} in stock.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        qty = item.quantity;
      }
    } catch (_) {}

    setState(() {
      if (qty <= 0) {
        _cart.remove(itemId);
      } else {
        _cart[itemId] = qty;
      }
    });
  }

  Future<void> _processOrder() async {
    if (_cart.isEmpty || _isProcessingCart) return;
    setState(() => _isProcessingCart = true);
    try {
      final items = _cart.entries.map((entry) {
        final item = widget.controller.allItems.firstWhere(
          (i) => i.id == entry.key,
        );
        return CustomerOrderItem(
          productId: item.id,
          productName: item.name,
          quantity: entry.value,
        );
      }).toList();

      await widget.controller.createCustomerOrder(items);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order sent to Helper!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _cart.clear());
      }
    } finally {
      if (mounted) setState(() => _isProcessingCart = false);
    }
  }

  double _calculateTotal() {
    double total = 0;
    for (var entry in _cart.entries) {
      try {
        final item = widget.controller.allItems.firstWhere(
          (i) => i.id == entry.key,
        );
        total += item.price * entry.value;
      } catch (_) {}
    }
    return total;
  }

  void _openAIObjectScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VisualSearchPage(
          controller: widget.controller,
          onSelectItem: (item) {
            if (_addToCart(item)) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${item.name} added to cart!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  void _showPendingOrdersModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.6,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Pending Orders',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<List<CustomerOrder>>(
                    stream: widget.controller.streamOrders(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final pendingOrders = snapshot.data!
                          .where(
                            (o) =>
                                o.status == 'prepared' || o.status == 'pending',
                          )
                          .toList();
                      if (pendingOrders.isEmpty) {
                        return const Center(
                          child: Text(
                            'No pending orders.',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: pendingOrders.length,
                        itemBuilder: (context, index) {
                          final o = pendingOrders[index];
                          final isReady = o.status == 'prepared';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isReady
                                    ? Colors.green.shade200
                                    : Colors.orange.shade200,
                              ),
                            ),
                            child: ExpansionTile(
                              leading: Icon(
                                isReady
                                    ? Icons.check_circle
                                    : Icons.hourglass_empty,
                                color: isReady ? Colors.green : Colors.orange,
                              ),
                              title: Text(
                                'Order #${o.id.substring(0, 8)} - ${isReady ? "Ready for Pickup" : "Being Prepared"}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text('${o.items.length} items'),
                              childrenPadding: const EdgeInsets.all(16),
                              children: [
                                const Divider(),
                                ...o.items.map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4.0,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.productName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          'Qty: ${item.quantity}',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (isReady)
                                  ElevatedButton.icon(
                                    icon: const Icon(
                                      Icons.check_circle_outline,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'Complete Transaction',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                    ),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text(
                                            'Confirm Completion',
                                          ),
                                          content: const Text(
                                            'Are you sure you want to complete this order?\n\nPlease confirm:\n• Payment is received\n• Receipt is created',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                              ),
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text(
                                                'Confirm',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await widget.controller.completeOrder(
                                          o,
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Transaction completed!',
                                              ),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        child: const Icon(
          Icons.image_not_supported,
          color: Colors.grey,
          size: 40,
        ),
      );
    }
    if (kIsWeb || imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: Colors.grey.shade200,
          child: const Icon(Icons.image_not_supported, color: Colors.grey),
        ),
      );
    } else {
      return Image.file(
        File(imageUrl),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: Colors.grey.shade200,
          child: const Icon(Icons.image_not_supported, color: Colors.grey),
        ),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 800;
          _isGridView ??= isDesktop;

          if (isDesktop) {
            return Row(
              children: [
                Expanded(flex: 2, child: _buildItemList()),
                const VerticalDivider(width: 1, color: Colors.grey),
                Expanded(flex: 1, child: _buildCartPanel()),
              ],
            );
          }

          final bottomInset = MediaQuery.of(context).padding.bottom;
          final totalHeight = constraints.maxHeight;
          final maxCartHeight = (totalHeight - 56 - bottomInset).clamp(
            0.0,
            totalHeight * _kSnapFull,
          );
          final minCartHeight = _kChromeOnlyHeightPx.clamp(0.0, maxCartHeight);

          final cartHeight = (totalHeight * _cartHeightFraction).clamp(
            minCartHeight,
            maxCartHeight,
          );

          return Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.only(bottom: cartHeight),
                  child: _buildItemList(),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: cartHeight,
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: _DraggableCartSheet(
                    onDragStart: (details) {
                      _snapAnim.stop();
                      _dragStart = details.globalPosition.dy;
                      _fractionAtDragStart = cartHeight / totalHeight;
                    },
                    onDragUpdate: (details) {
                      final delta = _dragStart - details.globalPosition.dy;
                      final newFraction =
                          _fractionAtDragStart + delta / totalHeight;
                      setState(() {
                        _cartHeightFraction = newFraction.clamp(
                          minCartHeight / totalHeight,
                          maxCartHeight / totalHeight,
                        );
                      });
                    },
                    onDragEnd: _onDragEnd,
                    child: _buildCartPanel(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Item list ──────────────────────────────────────────────────────────────
  Widget _buildItemList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search items...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(
                    _isGridView!
                        ? Icons.view_list_rounded
                        : Icons.grid_view_rounded,
                    color: Colors.black87,
                  ),
                  onPressed: () => setState(() => _isGridView = !_isGridView!),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(LucideIcons.scanLine, color: Colors.white),
                  onPressed: _openAIObjectScanner,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isGridView!
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    int crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
                    return GridView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 0.70,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        final cartQty = _cart[item.id] ?? 0;
                        final availableStock = item.quantity - cartQty;
                        // Trigger warning if available stock falls to 20% or less of max capacity
                        final isLowStock =
                            availableStock <= (item.maxQuantity * 0.20);
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          elevation: 2,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: SizedBox(
                                  width: double.infinity,
                                  child: _buildImage(item.imageUrl),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isLowStock
                                                ? Colors.red.shade100
                                                : Colors.green.shade100,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            "Stock: ${availableStock.toStringAsFixed(availableStock.truncateToDouble() == availableStock ? 0 : 2)}${item.unit}",
                                            style: TextStyle(
                                              color: isLowStock
                                                  ? Colors.red.shade900
                                                  : Colors.green.shade900,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "₱${item.price.toStringAsFixed(2)}",
                                          style: const TextStyle(
                                            color: Colors.orange,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        InkWell(
                                          onTap: availableStock > 0
                                              ? () => _addToCart(item)
                                              : null,
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: availableStock > 0
                                                  ? Colors.orange
                                                  : Colors.grey,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.add,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: _filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = _filteredItems[index];
                    final cartQty = _cart[item.id] ?? 0;
                    final availableStock = item.quantity - cartQty;
                    // Trigger warning if available stock falls to 20% or less of max capacity
                    final isLowStock =
                        availableStock <= (item.maxQuantity * 0.20);
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: _buildImage(item.imageUrl),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isLowStock
                                          ? Colors.red.shade100
                                          : Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      "Stock: ${availableStock.toStringAsFixed(availableStock.truncateToDouble() == availableStock ? 0 : 2)}${item.unit}",
                                      style: TextStyle(
                                        color: isLowStock
                                            ? Colors.red.shade900
                                            : Colors.green.shade900,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "₱${item.price.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: availableStock > 0
                                      ? () => _addToCart(item)
                                      : null,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: availableStock > 0
                                          ? Colors.orange
                                          : Colors.grey,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Cart panel ─────────────────────────────────────────────────────────────
  Widget _buildCartPanel() {
    return ClipRect(
      child: Container(
        color: Colors.white,
        child: Column(
          // FIX 2: mainAxisSize.min allows the column to not demand more
          // space than its children need — combined with Flexible below,
          // this prevents the overflow when the sheet is at minimum height.
          mainAxisSize: MainAxisSize.min,
          children: [
            // Orange header
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.orange,
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shopping_cart, color: Colors.black87),
                      const SizedBox(width: 12),
                      const Text(
                        'Current Order Cart',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_cart.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_cart.length}',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  StreamBuilder<List<CustomerOrder>>(
                    stream: widget.controller.streamOrders(),
                    builder: (context, snapshot) {
                      final pendingOrders = snapshot.hasData
                          ? snapshot.data!
                                .where(
                                  (o) =>
                                      o.status == 'prepared' ||
                                      o.status == 'pending',
                                )
                                .toList()
                          : <CustomerOrder>[];
                      if (pendingOrders.isEmpty) return const SizedBox.shrink();
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              Icons.receipt_long,
                              color: Colors.black87,
                              size: 28,
                            ),
                            onPressed: () => _showPendingOrdersModal(context),
                          ),
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${pendingOrders.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            // Smooth fade: the list area fades in as the panel opens and
            // fades out as it closes — no abrupt pop-in at a fixed threshold.
            // Opacity goes from 0→1 over the first 60px of available height.
            Flexible(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availH = constraints.maxHeight;
                  // Completely invisible and zero-effort when collapsed.
                  if (availH <= 0) return const SizedBox.shrink();
                  // Fade in over the first 60px of available space.
                  final opacity = (availH / 60.0).clamp(0.0, 1.0);
                  return AnimatedOpacity(
                    opacity: opacity,
                    duration: const Duration(milliseconds: 80),
                    child: ClipRect(
                      child: _cart.isEmpty
                          ? const Center(
                              child: Text(
                                'Cart is empty',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _cart.length,
                              itemBuilder: (context, index) {
                                final itemId = _cart.keys.elementAt(index);
                                final qty = _cart[itemId]!;
                                InventoryItem item;
                                try {
                                  item = widget.controller.allItems.firstWhere(
                                    (i) => i.id == itemId,
                                  );
                                } catch (_) {
                                  return const SizedBox.shrink();
                                }
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  color: Colors.white,
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              "₱${(item.price * qty).toStringAsFixed(2)}",
                                              style: const TextStyle(
                                                color: Colors.orange,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            _QuantityStepper(
                                              initialValue: qty,
                                              unit: item.unit,
                                              onChanged: (newQty) =>
                                                  _setCartQuantity(
                                                    itemId,
                                                    newQty,
                                                  ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                LucideIcons.trash2,
                                                color: Colors.redAccent,
                                              ),
                                              onPressed: () =>
                                                  _setCartQuantity(itemId, 0),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ), // ClipRect
                  ); // AnimatedOpacity
                },
              ), // LayoutBuilder
            ), // Flexible
            // Footer
            LayoutBuilder(
              builder: (context, footerConstraints) {
                final tight = footerConstraints.maxHeight < 90;

                final vPad = tight ? 8.0 : 14.0;
                final btnHeight = tight ? 38.0 : 48.0;
                final totalFontSize = tight ? 11.0 : 13.0;
                final amountFontSize = tight ? 16.0 : 20.0;
                final btnFontSize = tight ? 13.0 : 15.0;

                return Container(
                  constraints: BoxConstraints(
                    maxHeight: footerConstraints.maxHeight,
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: vPad),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: "TOTAL DUE  ",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: totalFontSize,
                                    color: Colors.grey.shade600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      "₱${_calculateTotal().toStringAsFixed(2)}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: amountFontSize,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _cart.isEmpty || _isProcessingCart
                              ? null
                              : _processOrder,
                          icon: _isProcessingCart
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.white,
                                  size: tight ? 16 : 20,
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            disabledBackgroundColor: Colors.grey,
                            minimumSize: Size(0, btnHeight),
                            padding: EdgeInsets.symmetric(
                              horizontal: tight ? 16 : 22,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(btnHeight),
                            ),
                          ),
                          label: Text(
                            _isProcessingCart
                                ? 'Processing...'
                                : 'Process Order',
                            style: TextStyle(
                              fontSize: btnFontSize,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Draggable sheet wrapper
// ─────────────────────────────────────────────────────────────────────────────
class _DraggableCartSheet extends StatelessWidget {
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final Widget child;

  const _DraggableCartSheet({
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 16,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      shadowColor: Colors.black26,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: onDragStart,
              onVerticalDragUpdate: onDragUpdate,
              onVerticalDragEnd: onDragEnd,
              child: Container(
                width: double.infinity,
                color: const Color(0xFFF5F5F5),
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
            // Cart content
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quantity stepper
// ─────────────────────────────────────────────────────────────────────────────
class _QuantityStepper extends StatefulWidget {
  final double initialValue;
  final String unit;
  final ValueChanged<double> onChanged;

  const _QuantityStepper({
    required this.initialValue,
    required this.unit,
    required this.onChanged,
  });

  @override
  State<_QuantityStepper> createState() => _QuantityStepperState();
}

class _QuantityStepperState extends State<_QuantityStepper> {
  late TextEditingController _controller;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _formatDisplay(widget.initialValue),
    );
  }

  @override
  void didUpdateWidget(covariant _QuantityStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue && !_isFocused) {
      _controller.text = _formatDisplay(widget.initialValue);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isSolidItem() {
    final u = widget.unit.toLowerCase();
    return u == 'pcs' || u == 'box' || u == 'pack' || u == '';
  }

  String _formatDisplay(double val) {
    if (_isSolidItem()) return val.toInt().toString();
    return val.truncateToDouble() == val
        ? val.toInt().toString()
        : val
              .toString()
              .replaceAll(RegExp(r'0*$'), '')
              .replaceAll(RegExp(r'\.$'), '');
  }

  String _getFractionLabel(double val) {
    if (val == 0) return "0";
    int whole = val.truncate();
    double decimal = val - whole;

    // Check for clean quarter-steps first — show nice fractions.
    String fraction = "";
    if ((decimal - 0.25).abs() < 0.001) {
      fraction = "1/4";
    } else if ((decimal - 0.50).abs() < 0.001)
      fraction = "1/2";
    else if ((decimal - 0.75).abs() < 0.001)
      fraction = "3/4";

    if (fraction.isNotEmpty) {
      // e.g. 1.5 → "1 1/2", 0.25 → "1/4"
      return whole == 0 ? fraction : "$whole $fraction";
    }

    // Not a quarter-step (e.g. 1.05, 1.20) — show the number cleanly.
    // Strip trailing zeros: 1.20 → "1.2", 1.00 → "1"
    if (decimal == 0) return whole.toString();
    final formatted = val
        .toStringAsFixed(3)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
    return formatted;
  }

  void _submit() {
    final val = double.tryParse(_controller.text);
    // When they submit (hit enter or tap away), if the value is exactly 0,
    // we go ahead and update it (which will trigger removal in the parent widget)
    if (val != null && val >= 0) {
      widget.onChanged(_isSolidItem() ? val.truncateToDouble() : val);
    } else {
      _controller.text = _formatDisplay(widget.initialValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSolid = _isSolidItem();
    final step = isSolid ? 1.0 : 0.25;
    final fractionLabel = !isSolid
        ? _getFractionLabel(widget.initialValue)
        : "";

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, color: Colors.orange),
          onPressed: () {
            if (widget.initialValue > step) {
              widget.onChanged(widget.initialValue - step);
            }
          },
        ),
        SizedBox(
          width: 50,
          child: Focus(
            onFocusChange: (hasFocus) {
              setState(() => _isFocused = hasFocus);
              if (!hasFocus) _submit();
            },
            child: TextField(
              controller: _controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.numberWithOptions(decimal: !isSolid),
              inputFormatters: isSolid
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              onChanged: (val) {
                final parsed = double.tryParse(val);
                // FIX: Only trigger the automatic update during typing if the value
                // is STRICTLY GREATER than 0. This stops the text field from destroying
                // itself the second you type a "0" for measurements like "0.5".
                if (parsed != null && parsed > 0) {
                  widget.onChanged(
                    isSolid ? parsed.truncateToDouble() : parsed,
                  );
                }
              },
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.orange),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.orange, width: 2),
                ),
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, color: Colors.orange),
          onPressed: () => widget.onChanged(widget.initialValue + step),
        ),
        if (!isSolid)
          Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Text(
              fractionLabel.isNotEmpty
                  ? "$fractionLabel ${widget.unit}"
                  : widget.unit,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }
}
