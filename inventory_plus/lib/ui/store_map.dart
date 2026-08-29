import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../data/inventory.dart';
import '../logic/inventory_controller.dart';

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

class _StoreMapState extends State<StoreMap>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _bounceAnimation;
  String? _activeElementId;
  final TransformationController _transformationController =
      TransformationController();
  bool _isInitialScaleSet = false;
  MapElement? _selectedPopupElement;
  late final GlobalKey _mapKey = GlobalKey();

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

  List<Offset> _getCorners(Offset pos, Size size, double rotation) {
    final double cx = pos.dx + size.width / 2;
    final double cy = pos.dy + size.height / 2;
    final double w2 = size.width / 2;
    final double h2 = size.height / 2;
    
    final double cosR = math.cos(rotation);
    final double sinR = math.sin(rotation);
    
    return [
      Offset(cx - w2 * cosR + h2 * sinR, cy - w2 * sinR - h2 * cosR), // TL
      Offset(cx + w2 * cosR + h2 * sinR, cy + w2 * sinR - h2 * cosR), // TR
      Offset(cx + w2 * cosR - h2 * sinR, cy + w2 * sinR + h2 * cosR), // BR
      Offset(cx - w2 * cosR - h2 * sinR, cy - w2 * sinR + h2 * cosR), // BL
    ];
  }

  bool _hasCollision(MapElement activeEl, Offset pos, Size size, double rot) {
    final cornersA = _getCorners(pos, size, rot);
    final axesA = [
      Offset(math.cos(rot), math.sin(rot)),
      Offset(-math.sin(rot), math.cos(rot)),
    ];

    for (var other in widget.controller.storeLayout) {
      if (other.id == activeEl.id) continue;
      
      final cornersB = _getCorners(other.position, other.size, other.rotation);
      final axesB = [
        Offset(math.cos(other.rotation), math.sin(other.rotation)),
        Offset(-math.sin(other.rotation), math.cos(other.rotation)),
      ];

      final allAxes = [...axesA, ...axesB];
      bool overlap = true;

      for (var axis in allAxes) {
        double minA = double.infinity, maxA = -double.infinity;
        for (var p in cornersA) {
          final proj = p.dx * axis.dx + p.dy * axis.dy;
          if (proj < minA) minA = proj;
          if (proj > maxA) maxA = proj;
        }

        double minB = double.infinity, maxB = -double.infinity;
        for (var p in cornersB) {
          final proj = p.dx * axis.dx + p.dy * axis.dy;
          if (proj < minB) minB = proj;
          if (proj > maxB) maxB = proj;
        }

        if (maxA <= minB || maxB <= minA) {
          overlap = false; // Gap found, they do not overlap on this axis
          break;
        }
      }

      if (overlap) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: widget.mode == MapMode.view
          ? const EdgeInsets.symmetric(vertical: 8)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: widget.mode == MapMode.view
            ? BorderRadius.circular(12)
            : BorderRadius.zero,
        border: widget.mode == MapMode.view
            ? Border.all(color: Colors.grey.shade800)
            : null,
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
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
              double scale =
                  math.min(scaleX, scaleY) *
                  0.9; // 90% of screen to add padding
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
          boundaryMargin: const EdgeInsets.all(double.infinity),
          child: Builder(
            builder: (BuildContext dropContext) {
              return DragTarget<ElementType>(
                onAcceptWithDetails: (details) {
                  final RenderBox box =
                      dropContext.findRenderObject() as RenderBox;
                  final Offset localOffset = box.globalToLocal(details.offset);

                  final newEl = MapElement(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    type: details.data,
                    position: localOffset,
                    label: details.data.name.toUpperCase(),
                  );

                  if (!_hasCollision(newEl, localOffset, newEl.size, newEl.rotation)) {
                    setState(() {
                      widget.controller.storeLayout.add(newEl);
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Cannot place element here. It overlaps with another."),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                },
                  // builder: (context, candidateData, rejectedData) {
                  // return GestureDetector(
                  //   onTap: () {
                  //     if (widget.mode == MapMode.manage) {
                  //       setState(() {
                  //         _activeElementId = null;
                  //       });
                  //     }
                  //   },
                  //   child: Container(
                  //     key: _mapKey,
                  //     width: mapWidth,
                  //     height: mapHeight,
                  //     decoration: BoxDecoration(
                  //       color: const Color(0xFF1E293B),
                  //       border: Border.all(color: Colors.blueGrey, width: 2),
                  //     ),
                  //     child: Stack(
                  //       clipBehavior: Clip.hardEdge,
                  //       children: [
                  //         CustomPaint(
                  //           painter: GridPainter(),
                  //           size: Size(mapWidth, mapHeight),
                  //         ),
                  //         ...sortedLayout.map(
                  //           (el) => _buildPhysicalElement(el),
                  //         ),
                  //       ],
                  //     ),
                  //   ),
                  // );
                  
                // },
                builder: (context, candidateData, rejectedData) {
                  return GestureDetector(
                    onTap: () {
                      if (widget.mode == MapMode.manage) {
                        setState(() {
                          _activeElementId = null;
                        });
                      } else if (widget.mode == MapMode.view) {
                        setState(() {
                          _selectedPopupElement = null; // Close popup when tapping empty space
                        });
                      }
                    },
                    child: Container(
                      key: _mapKey,
                      width: mapWidth,
                      height: mapHeight,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        border: Border.all(color: Colors.blueGrey, width: 2),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none, // Changed to none so popup can overflow edge safely
                        children: [
                          CustomPaint(
                            painter: GridPainter(),
                            size: Size(mapWidth, mapHeight),
                          ),
                          ...sortedLayout.map(
                            (el) => _buildPhysicalElement(el),
                          ),
                          // Add the popup to the top of the stack!
                          if (_selectedPopupElement != null) 
                            _buildFloatingPopup(mapWidth),
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
    // Removed the "if (isHighlighted) return Colors.orange;" 
    // Now it keeps its proper category color!
    switch (type) {
      case ElementType.door:
        return Colors.green;
      case ElementType.rack:
        return Colors.blue;
      case ElementType.shelf:
        return Colors.brown;
      case ElementType.cashier:
        return Colors.purple;
      case ElementType.pathway:
        return Colors.blueGrey;
    }
  }

  Widget _buildPhysicalElement(MapElement el) {
    final bool isHighlighted = el.id == widget.highlightId;
    final bool isActive =
        el.id == _activeElementId && widget.mode == MapMode.manage;

    String displayLabel = el.label;

    final assignedItems = widget.controller.allItems
        .where((item) => item.locationId == el.id)
        .toList();

    if (assignedItems.isNotEmpty) {
      // Sort items by shelfLevel to display hierarchically
      assignedItems.sort(
        (a, b) => (a.shelfLevel ?? '').compareTo(b.shelfLevel ?? ''),
      );
      displayLabel = assignedItems
          .map((item) {
            final level =
                (item.shelfLevel != null && item.shelfLevel!.trim().isNotEmpty)
                ? " (Lvl ${item.shelfLevel})"
                : "";
            return "- ${item.name}$level";
          })
          .join("\n");
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
        boxShadow: const [
          BoxShadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 3),
        ],
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Text(
            displayLabel,
            textAlign: assignedItems.isNotEmpty
                ? TextAlign.left
                : TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              color: Colors.white,
            ),
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
      child: Transform.rotate(
        angle: el.rotation,
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
                } else if (widget.mode == MapMode.selection &&
                    widget.selectedItemId != null) {
                  if (el.type == ElementType.door ||
                      el.type == ElementType.pathway ||
                      el.type == ElementType.cashier) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Cannot assign items to ${el.type.name}s.",
                        ),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    return;
                  }
                  await widget.controller.assignItemToLocation(
                    widget.selectedItemId!,
                    el.id,
                  );

                  if (mounted) {
                    if (widget.onSelectionAssigned != null) {
                      widget.onSelectionAssigned!();
                    }
                    setState(
                      () {},
                    ); // Force the map element to instantly redraw its text
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Item assigned to location!",
                          style: TextStyle(color: Colors.white),
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else if (widget.mode == MapMode.pick) {
                  if (el.type == ElementType.door ||
                      el.type == ElementType.pathway ||
                      el.type == ElementType.cashier) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Cannot assign items to ${el.type.name}s.",
                        ),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    return;
                  }
                  if (widget.onElementSelected != null) {
                    widget.onElementSelected!(el);
                  }
                }
                else if (widget.mode == MapMode.view) {
                  if (el.type != ElementType.door && 
                      el.type != ElementType.pathway && 
                      el.type != ElementType.cashier) {
                    setState(() {
                      // Toggle off if clicking the same one, otherwise show new
                      if (_selectedPopupElement?.id == el.id) {
                        _selectedPopupElement = null;
                      } else {
                        _selectedPopupElement = el;
                      }
                    });
                  }
                }
              },
              onPanUpdate: widget.mode == MapMode.manage
                  ? (details) {
                      setState(() {
                        _activeElementId = el.id;
                        final double cosR = math.cos(el.rotation);
                        final double sinR = math.sin(el.rotation);
                        final double mapDx = details.delta.dx * cosR - details.delta.dy * sinR;
                        final double mapDy = details.delta.dx * sinR + details.delta.dy * cosR;
                        final Offset newPos = el.position + Offset(mapDx, mapDy);
                        if (!_hasCollision(el, newPos, el.size, el.rotation)) {
                          el.position = newPos;
                        }
                      });
                    }
                  : null,
              onPanEnd: widget.mode == MapMode.manage
                  ? (details) {
                      // Auto-save removed; wait for manual save
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
                    return Transform.rotate(
                      angle: -el.rotation,
                      child: Transform.translate(
                        offset: Offset(
                          0,
                          _bounceAnimation.value - 20.0,
                        ), // Hover above 2D object
                        child: const Icon(
                          LucideIcons.mapPin,
                          color: Colors.orange,
                          size: 28,
                        ),
                      ),
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
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 4),
                    ],
                  ),
                  child: const Icon(
                    LucideIcons.x,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          if (widget.mode == MapMode.manage && isActive)
            Positioned(
              right: 5,
              top: 5,
              child: GestureDetector(
                onPanUpdate: (details) {
                  if (_mapKey.currentContext != null) {
                    final RenderBox mapBox = _mapKey.currentContext!.findRenderObject() as RenderBox;
                    final Offset localPosition = mapBox.globalToLocal(details.globalPosition);
                    final Offset center = Offset(el.position.dx + el.size.width / 2, el.position.dy + el.size.height / 2);
                    
                    final double angle = math.atan2(localPosition.dy - center.dy, localPosition.dx - center.dx);
                    final double handleAngle = math.atan2(-el.size.height / 2 - 15, el.size.width / 2 + 15);
                    
                    final double newRot = angle - handleAngle;

                    setState(() {
                      if (!_hasCollision(el, el.position, el.size, newRot)) {
                        el.rotation = newRot;
                      }
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 4),
                    ],
                  ),
                  child: const Icon(
                    LucideIcons.rotateCw,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          if (widget.mode == MapMode.manage && isActive)
            Positioned(
              left: 5,
              bottom: 5,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    final double cosR = math.cos(el.rotation);
                    final double sinR = math.sin(el.rotation);
                    
                    // details.delta is already in the rotated element's local coordinate space
                    final double localDx = details.delta.dx;
                    final double localDy = details.delta.dy;

                    double newWidth = el.size.width - localDx; // drag left increases width
                    double newHeight = el.size.height + localDy; // drag down increases height

                    if (newWidth < 40) newWidth = 40;
                    if (newHeight < 40) newHeight = 40;

                    // Anchor calculation: Lock the Top-Right corner in place locally since resizing is via Bottom-Left
                    final Offset oldCenter = Offset(el.position.dx + el.size.width / 2, el.position.dy + el.size.height / 2);
                    final Offset oldAnchorLocal = Offset(el.size.width / 2, -el.size.height / 2);
                    final Offset oldAnchorGlobal = oldCenter + Offset(
                      oldAnchorLocal.dx * cosR - oldAnchorLocal.dy * sinR,
                      oldAnchorLocal.dx * sinR + oldAnchorLocal.dy * cosR,
                    );

                    final Offset newAnchorLocal = Offset(newWidth / 2, -newHeight / 2);
                    final Offset newAnchorRotated = Offset(
                      newAnchorLocal.dx * cosR - newAnchorLocal.dy * sinR,
                      newAnchorLocal.dx * sinR + newAnchorLocal.dy * cosR,
                    );
                    
                    final Offset newCenter = oldAnchorGlobal - newAnchorRotated;
                    final Offset newPosition = newCenter - Offset(newWidth / 2, newHeight / 2);

                    if (!_hasCollision(el, newPosition, Size(newWidth, newHeight), el.rotation)) {
                      el.size = Size(newWidth, newHeight);
                      el.position = newPosition;
                    }
                  });
                },
                onPanEnd: (details) {
                  // Auto-save removed; wait for manual save
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 4),
                    ],
                  ),
                  child: const Icon(
                    Icons.open_in_full,
                    size: 12,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }
Widget _buildFloatingPopup(double mapWidth) {
    final el = _selectedPopupElement!;
    final assignedItems = widget.controller.allItems
        .where((item) => item.locationId == el.id)
        .toList();

    // Position it slightly to the right of the element
    double px = el.position.dx + el.size.width + 15;
    double py = el.position.dy - 10;

    // If it's too close to the right edge, flip it to the left side
    if (px + 200 > mapWidth) {
      px = el.position.dx - 215;
    }

    return Positioned(
      left: px,
      top: py,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              )
            ],
            border: Border.all(color: Colors.orange, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        el.label,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _selectedPopupElement = null),
                      child: const Icon(LucideIcons.x, size: 14, color: Colors.black54),
                    )
                  ],
                ),
              ),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                child: assignedItems.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Text("Empty", style: TextStyle(color: Colors.grey, fontSize: 11)),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: assignedItems.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = assignedItems[index];
                          return Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("SKU: ${item.sku}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    Text("Qty: ${item.quantity}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
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
          _buildDetailItem(
            "Layer",
            (widget.location as dynamic)?.layer?.toString() ?? "N/A",
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }


  void _showElementDetails(MapElement el, List<InventoryItem> items) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(maxHeight: 500, maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      el.label,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
                const Divider(),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text("This location is currently empty.", style: TextStyle(color: Colors.grey)),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text("SKU: ${item.sku} • Lvl: ${item.shelfLevel ?? 'N/A'}"),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "Qty: ${item.quantity} ${item.unit}", 
                                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)
                              ),
                              Text(
                                "₱${item.price.toStringAsFixed(2)}", 
                                style: const TextStyle(fontSize: 12, color: Colors.grey)
                              ),
                            ],
                          ),
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
