import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../data/inventory.dart';
import '../../logic/inventory_controller.dart';

enum MapMode { view, manage, selection, pick }

class StoreMap extends StatefulWidget {
  final InventoryController controller;
  final String? highlightId;    
  final ItemLocation? location; 
  final String? itemName;
  final MapMode mode;
  final String? selectedItemId;
  final VoidCallback? onSelectionAssigned;
  final Function(MapElement)? onElementSelected;

  const StoreMap({
    super.key,
    required this.controller,
    this.highlightId,
    this.location,
    this.itemName,
    this.mode = MapMode.view,
    this.selectedItemId,
    this.onSelectionAssigned,
    this.onElementSelected,
  });

  @override
  State<StoreMap> createState() => _StoreMapState();
}

class _StoreMapState extends State<StoreMap> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _bounceAnimation;
  String? _activeElementId;
  final TransformationController _transformationController = TransformationController();
  bool _isInitialScaleSet = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: widget.mode == MapMode.view ? const EdgeInsets.symmetric(vertical: 8) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: widget.mode == MapMode.view ? BorderRadius.circular(12) : BorderRadius.zero,
        border: widget.mode == MapMode.view ? Border.all(color: Colors.grey.shade800) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (widget.mode == MapMode.view) _buildHeader(),
          _buildLiveMapDisplay(),
          if (widget.location != null) _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF0F172A),
      child: Row(
        children: [
                const Icon(LucideIcons.mapPin, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Store Map",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      if (widget.itemName != null)
                        Text(
                          widget.itemName!,
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildLiveMapDisplay() {
    double mapWidth = 1000;
    double mapHeight = 1000;

    for (var el in widget.controller.storeLayout) {
      if (el.position.dx + el.size.width + 100 > mapWidth) {
        mapWidth = el.position.dx + el.size.width + 100;
      }
      if (el.position.dy + el.size.height + 100 > mapHeight) {
        mapHeight = el.position.dy + el.size.height + 100;
      }
    }

    // Depth sort: Elements furthest away (smaller X + Y in this rotated view) must paint first
    var sortedLayout = List<MapElement>.from(widget.controller.storeLayout);
    sortedLayout.sort((a, b) {
      if (a.id == _activeElementId) return 1;
      if (b.id == _activeElementId) return -1;
      double distA = a.position.dx + a.position.dy;
      double distB = b.position.dx + b.position.dy;
      return distA.compareTo(distB);
    });

    Widget map = LayoutBuilder(
      builder: (context, constraints) {
        if (!_isInitialScaleSet && constraints.maxWidth > 0) {
          _isInitialScaleSet = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              double scaleX = constraints.maxWidth / mapWidth;
              double scaleY = constraints.maxHeight / mapHeight;
              double scale = math.min(scaleX, scaleY) * 0.9; // 90% of screen to add padding
              scale = scale.clamp(0.1, 2.5);

              double dx = (constraints.maxWidth - (mapWidth * scale)) / 2;
              double dy = (constraints.maxHeight - (mapHeight * scale)) / 2;

              _transformationController.value = Matrix4.identity()
                ..translate(dx, dy)
                ..scale(scale);
            }
          });
        }

        return InteractiveViewer(
              transformationController: _transformationController,
              constrained: false,
              minScale: 0.1,
              maxScale: 2.5,
              boundaryMargin: const EdgeInsets.all(200),
              child: Builder(
                builder: (BuildContext dropContext) {
                  return DragTarget<ElementType>(
                    onAcceptWithDetails: (details) {
                      final RenderBox box = dropContext.findRenderObject() as RenderBox;
                      final Offset localOffset = box.globalToLocal(details.offset);

                      setState(() {
                        widget.controller.storeLayout.add(MapElement(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          type: details.data,
                          position: localOffset,
                          label: details.data.name.toUpperCase(),
                        ));
                      });
                      widget.controller.saveLayout();
                    },
                    builder: (context, candidateData, rejectedData) {
                      return GestureDetector(
                        onTap: () {
                          if (widget.mode == MapMode.manage) {
                            setState(() {
                              _activeElementId = null;
                            });
                          }
                        },
                        child: Container(
                          width: mapWidth,
                          height: mapHeight,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            border: Border.all(color: Colors.blueGrey, width: 2),
                          ),
                          child: Stack(
                            clipBehavior: Clip.hardEdge,
                            children: [
                              CustomPaint(
                                painter: GridPainter(),
                                size: Size(mapWidth, mapHeight),
                              ),
                              ...sortedLayout.map((el) => _buildPhysicalElement(el)),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            );
      },
    );

    if (widget.mode == MapMode.view) {
      return Container(
        height: 400,
        width: double.infinity,
        color: const Color(0xFF0F172A),
        child: map,
      );
    } else {
      return Expanded(
        child: Container(
          width: double.infinity,
          color: const Color(0xFF0F172A),
          child: map,
        ),
      );
    }
  }

  Color _getElementColor(ElementType type, bool isHighlighted) {
    if (isHighlighted) return Colors.orange;
    switch (type) {
      case ElementType.door: return Colors.green;
      case ElementType.rack: return Colors.blue;
      case ElementType.shelf: return Colors.brown;
      case ElementType.cashier: return Colors.purple;
      case ElementType.pathway: return Colors.blueGrey;
    }
  }

  Widget _buildPhysicalElement(MapElement el) {
    final bool isHighlighted = el.id == widget.highlightId;
    final bool isActive = el.id == _activeElementId && widget.mode == MapMode.manage;

    String displayLabel = el.label; 
    
<<<<<<< Updated upstream
    final assignedItems = widget.controller.allItems
        .where((item) => item.locationId == el.id)
        .toList();

    if (assignedItems.isNotEmpty) {
      // Sort items by shelfLevel to display hierarchically
      assignedItems.sort((a, b) => (a.shelfLevel ?? '').compareTo(b.shelfLevel ?? ''));
      displayLabel = assignedItems.map((item) {
        final level = (item.shelfLevel != null && item.shelfLevel!.trim().isNotEmpty) ? " (Lvl ${item.shelfLevel})" : "";
        return "- ${item.name}$level";
      }).join("\n");
=======
    try {
      final assignedItem = widget.controller.allItems.firstWhere(
        (item) => item.locationId == el.id,
      );
      displayLabel = assignedItem.name; 
    } catch (e) {
      // fdsfsd
>>>>>>> Stashed changes
    }

    Color baseColor = _getElementColor(el.type, isHighlighted);

    Widget shelf = Container(
      width: el.size.width,
      height: el.size.height,
      decoration: BoxDecoration(
        color: baseColor.withOpacity(0.7),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isActive ? Colors.yellowAccent : baseColor,
          width: isActive ? 3 : 1,
        ),
        boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 3)],
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Text(
            displayLabel,
            textAlign: assignedItems.isNotEmpty ? TextAlign.left : TextAlign.center,
            style: TextStyle(fontSize: 10, fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal, color: Colors.white),
            maxLines: 10,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );

    return Positioned(
      key: ValueKey(el.id),
      left: el.position.dx - 20,
      top: el.position.dy - 20,
      width: el.size.width + 40,
      height: el.size.height + 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 20,
            top: 20,
            child: GestureDetector(
            onTap: () async {
              if (widget.mode == MapMode.manage) {
                setState(() {
                  _activeElementId = el.id;
                });
              } else if (widget.mode == MapMode.selection && widget.selectedItemId != null) {
                await widget.controller.assignItemToLocation(widget.selectedItemId!, el.id);
                
                if (mounted) {
                  if (widget.onSelectionAssigned != null) {
                    widget.onSelectionAssigned!();
                  }
                  setState(() {}); // Force the map element to instantly redraw its text
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Item assigned to location!", style: TextStyle(color: Colors.white)),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } else if (widget.mode == MapMode.pick) {
                if (widget.onElementSelected != null) {
                  widget.onElementSelected!(el);
                }
              }
            },
            onPanUpdate: widget.mode == MapMode.manage
                ? (details) {
                    setState(() {
                      _activeElementId = el.id;
                      el.position += details.delta;
                    });
                  }
                : null,
            onPanEnd: widget.mode == MapMode.manage
                ? (details) {
                    widget.controller.saveLayout();
                  }
                : null,
            onLongPress: null,
            child: shelf,
          ),
          ),
          
          if (isHighlighted)
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: AnimatedBuilder(
                  animation: _bounceAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _bounceAnimation.value - 20.0), // Hover above 2D object
                      child: const Icon(LucideIcons.mapPin, color: Colors.orange, size: 28),
                    );
                  },
                ),
              ),
            ),

          if (isActive)
            Positioned(
              left: 5,
              top: 5,
              child: GestureDetector(
                onTap: () {
                  widget.controller.deleteMapElement(el.id);
                  setState(() {
                    _activeElementId = null;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: const Icon(LucideIcons.x, size: 14, color: Colors.white),
                ),
              ),
            ),
            
          if (widget.mode == MapMode.manage && isActive)
            Positioned(
              right: 10,
              bottom: 10,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    double newWidth = el.size.width + details.delta.dx;
                    double newHeight = el.size.height + details.delta.dy;

                    el.size = Size(
                      newWidth < 40 ? 40 : newWidth,
                      newHeight < 40 ? 40 : newHeight,
                    );
                  });
                },
                onPanEnd: (details) {
                  widget.controller.saveLayout();
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: const Icon(Icons.open_in_full, size: 12, color: Colors.black),
                ),
              ),
            ),
        ],
      ),
    );
  }
 
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF1E293B),
      child: Row(
        children: [
          _buildDetailItem("Aisle", widget.location?.aisle ?? "N/A"),
          const SizedBox(width: 8),
          _buildDetailItem("Shelf", widget.location?.shelf.toString() ?? "N/A"),
          const SizedBox(width: 8),
          _buildDetailItem("Section", widget.location?.section ?? "N/A"),
          const SizedBox(width: 8),
          _buildDetailItem("Layer", (widget.location as dynamic)?.layer?.toString() ?? "N/A"),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueGrey.withOpacity(0.3)
      ..strokeWidth = 1;
      
    const double step = 50;
    
    for (double i = 0; i <= size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i <= size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}