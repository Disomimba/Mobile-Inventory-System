import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../data/inventory.dart';
import '../logic/inventory_controller.dart';
import 'visual_search_page.dart';

class PosCartPage extends StatefulWidget {
  final InventoryController controller;

  const PosCartPage({super.key, required this.controller});

  @override
  State<PosCartPage> createState() => _PosCartPageState();
}

class _PosCartPageState extends State<PosCartPage> {
  String _searchQuery = '';
  final Map<String, int> _cart = {};
  bool _isGridView = true;

  List<InventoryItem> get _filteredItems => widget.controller.searchInventory(_searchQuery);

  bool _addToCart(InventoryItem item) {
    if (item.quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.name} is out of stock!'), backgroundColor: Colors.red),
      );
      return false;
    }
    
    final currentQty = _cart[item.id] ?? 0;
    if (currentQty >= item.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot add more of ${item.name}. Stock limit reached.'), backgroundColor: Colors.orange),
      );
      return false;
    }

    setState(() {
      _cart[item.id] = currentQty + 1;
    });
    return true;
  }

  void _removeFromCart(String itemId) {
    setState(() {
      if (_cart.containsKey(itemId)) {
        if (_cart[itemId]! > 1) {
          _cart[itemId] = _cart[itemId]! - 1;
        } else {
          _cart.remove(itemId);
        }
      }
    });
  }

  void _setCartQuantity(String itemId, int qty) {
    try {
      final item = widget.controller.allItems.firstWhere((i) => i.id == itemId);
      if (qty > item.quantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot set quantity to $qty. Only ${item.quantity} in stock.'), backgroundColor: Colors.orange),
        );
        qty = item.quantity;
      }
    } catch (e) {
      // Item might have been deleted from inventory
    }

    setState(() {
      if (qty <= 0) {
        _cart.remove(itemId);
      } else {
        _cart[itemId] = qty;
      }
    });
  }

  Future<void> _processOrder() async {
    if (_cart.isEmpty) return;
    
    final items = _cart.entries.map((entry) {
      final item = widget.controller.allItems.firstWhere((i) => i.id == entry.key);
      return CustomerOrderItem(
        productId: item.id,
        productName: item.name,
        quantity: entry.value,
      );
    }).toList();

    await widget.controller.createCustomerOrder(items);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order sent to Helper!'), backgroundColor: Colors.green),
      );
      setState(() {
        _cart.clear();
      });
    }
  }

  double _calculateTotal() {
    double total = 0;
    for (var entry in _cart.entries) {
      try {
        final item = widget.controller.allItems.firstWhere((i) => i.id == entry.key);
        total += item.price * entry.value;
      } catch (e) {
        // Handle if an item was deleted from inventory but is still somehow in the local cart.
      }
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
                SnackBar(content: Text('${item.name} added to cart!'), backgroundColor: Colors.green),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
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
                    const Text('Pending Orders', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<List<CustomerOrder>>(
                    stream: widget.controller.streamOrders(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final pendingOrders = snapshot.data!.where((o) => o.status == 'prepared' || o.status == 'pending').toList();
                      if (pendingOrders.isEmpty) return const Center(child: Text('No pending orders.', style: TextStyle(color: Colors.grey, fontSize: 16)));

                      return ListView.builder(
                        itemCount: pendingOrders.length,
                        itemBuilder: (context, index) {
                          final o = pendingOrders[index];
                          final isReady = o.status == 'prepared';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isReady ? Colors.green.shade200 : Colors.orange.shade200)),
                            child: ListTile(
                              leading: Icon(
                                isReady ? Icons.check_circle : Icons.hourglass_empty,
                                color: isReady ? Colors.green : Colors.orange,
                              ),
                              title: Text('Order #${o.id.substring(0, 8)} - ${isReady ? "Ready for Pickup" : "Being Prepared"}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${o.items.length} items'),
                              trailing: isReady ? ElevatedButton.icon(
                                icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
                                label: const Text('Complete', style: TextStyle(color: Colors.white, fontSize: 12)),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Confirm Completion'),
                                      content: const Text('Are you sure you want to complete this order?\n\nPlease confirm:\n• Payment is received\n• Receipt is printed/sent'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text('Confirm', style: TextStyle(color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    await widget.controller.completeOrder(o);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Transaction completed! Stock deducted.'), backgroundColor: Colors.green),
                                      );
                                    }
                                  }
                                },
                              ) : null,
                            ),
                          );
                        },
                      );
                    }
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
        child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 40),
      );
    }
    if (kIsWeb || imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey.shade200,
          child: const Icon(Icons.image_not_supported, color: Colors.grey),
        ),
      );
    } else {
      return Image.file(
        File(imageUrl),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey.shade200,
          child: const Icon(Icons.image_not_supported, color: Colors.grey),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 800;
          
          if (isDesktop) {
            return Row(
              children: [
                Expanded(flex: 2, child: _buildItemList()),
                const VerticalDivider(width: 1, color: Colors.grey),
                Expanded(flex: 1, child: _buildCartPanel()),
              ],
            );
          } else {
            return Column(
              children: [
                Expanded(flex: 3, child: _buildItemList()),
                const Divider(height: 1, color: Colors.grey),
                Expanded(flex: 2, child: _buildCartPanel()),
              ],
            );
          }
        }
      ),
    );
  }

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
                    _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                    color: Colors.black87,
                  ),
                  onPressed: () => setState(() => _isGridView = !_isGridView),
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
          child: StreamBuilder(
            // We listen to the order stream as an indirect way to trigger a rebuild
            // of the inventory list when an order is completed, which affects stock.
            stream: widget.controller.streamOrders(),
            builder: (context, snapshot) {
              return _isGridView
                  ? LayoutBuilder(builder: (context, constraints) {
                      int crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
                      return GridView.builder(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 0.70,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = _filteredItems[index];
                          final isLowStock = item.quantity <= 10;
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            elevation: 2,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
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
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.name,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isLowStock
                                                  ? Colors.red.shade100
                                                  : Colors.green.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              "Stock: ${item.quantity}",
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
                                            "\$${item.price.toStringAsFixed(2)}",
                                            style: const TextStyle(
                                              color: Colors.orange,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () => _addToCart(item),
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: item.quantity > 0 ? Colors.orange : Colors.grey,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Icon(Icons.add,
                                                  color: Colors.white, size: 20),
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
                    })
                  : ListView.builder(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        final isLowStock = item.quantity <= 10;
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12),
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
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
                                            fontSize: 14),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isLowStock
                                              ? Colors.red.shade100
                                              : Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          "Stock: ${item.quantity}",
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
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "\$${item.price.toStringAsFixed(2)}",
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    InkWell(
                                      onTap: () => _addToCart(item),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: item.quantity > 0 ? Colors.orange : Colors.grey,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.add,
                                            color: Colors.white, size: 20),
                                      ),
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
          ),
        ),
      ],
    );
  }

  Widget _buildCartPanel() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.orange,
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shopping_cart, color: Colors.black87),
                    SizedBox(width: 12),
                    Text('Current Order Cart', style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                StreamBuilder<List<CustomerOrder>>(
                  stream: widget.controller.streamOrders(),
                  builder: (context, snapshot) {
                    final pendingOrders = snapshot.hasData ? snapshot.data!.where((o) => o.status == 'prepared' || o.status == 'pending').toList() : <CustomerOrder>[];
                    if (pendingOrders.isEmpty) return const SizedBox.shrink();
                    
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.receipt_long, color: Colors.black87, size: 28),
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
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                ),
              ],
            ),
          ),
          Expanded(
            child: _cart.isEmpty
                ? const Center(child: Text('Cart is empty', style: TextStyle(color: Colors.grey, fontSize: 16)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _cart.length,
                    itemBuilder: (context, index) {
                      final itemId = _cart.keys.elementAt(index);
                      final qty = _cart[itemId]!;
                      InventoryItem item;
                      try {
                        item = widget.controller.allItems.firstWhere((i) => i.id == itemId);
                      } catch (e) {
                        return const SizedBox.shrink();
                      }
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        color: Colors.white,
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                                  Text("\$${(item.price * qty).toStringAsFixed(2)}", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _QuantityStepper(
                                    initialValue: qty,
                                    onChanged: (newQty) => _setCartQuantity(itemId, newQty),
                                  ),
                                  IconButton(
                                    icon: const Icon(LucideIcons.trash2, color: Colors.redAccent),
                                    onPressed: () => _setCartQuantity(itemId, 0),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("TOTAL DUE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                    Text("\$${_calculateTotal().toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.black)),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _cart.isEmpty ? null : _processOrder,
                  icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[800],
                    disabledBackgroundColor: Colors.grey,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  label: const Text('Process Order', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityStepper extends StatefulWidget {
  final int initialValue;
  final ValueChanged<int> onChanged;

  const _QuantityStepper({required this.initialValue, required this.onChanged});

  @override
  State<_QuantityStepper> createState() => _QuantityStepperState();
}

class _QuantityStepperState extends State<_QuantityStepper> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue.toString());
  }

  @override
  void didUpdateWidget(covariant _QuantityStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      _controller.text = widget.initialValue.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final val = int.tryParse(_controller.text);
    if (val != null && val >= 0) {
      widget.onChanged(val);
    } else {
      _controller.text = widget.initialValue.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, color: Colors.orange),
          onPressed: () {
            if (widget.initialValue > 1) {
              widget.onChanged(widget.initialValue - 1);
            }
          },
        ),
        SizedBox(
          width: 50,
          child: Focus(
            onFocusChange: (hasFocus) {
              if (!hasFocus) _submit();
            },
            child: TextField(
              controller: _controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                border: UnderlineInputBorder(),
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, color: Colors.orange),
          onPressed: () => widget.onChanged(widget.initialValue + 1),
        ),
      ],
    );
  }
}