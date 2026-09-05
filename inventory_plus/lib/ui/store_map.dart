import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../data/inventory.dart';
import '../logic/inventory_controller.dart';
import 'models_3d.dart';

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

  Offset? _dragPreviewPos;
  Size? _dragPreviewSize;
  bool _dragPreviewValid = true;
  double _dragPreviewRotation = 0.0;
  Offset? _rawDragPosition;

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

  Size _getDefaultSize(ElementType type) {
    if (type == ElementType.wall || type.name == 'pathway') {
      return const Size(15, 15); // Start as a 15x15 pillar
    } else if (type == ElementType.door) {
      // Changed to 15 depth so it perfectly matches the wall thickness!
      return const Size(80, 15); 
    } else if (type == ElementType.cashier) {
      return const Size(168, 64); // Wider counter
    } else if (type == ElementType.shelf) {
      return const Size(104, 48); // Standard shelf footprint
    } else if (type == ElementType.rack) {
      return const Size(120, 60); // Standard rack footprint
    }
    return const Size(80, 80); // Fallback
  }

  Offset _snapToGrid(Offset position, Size size, ElementType type) {
    const double step = 40.0;

    if (type == ElementType.wall) {
      // WALL: Center snaps to the grid lines (0, 40, 80...)
      final Offset center = position + Offset(size.width / 2, size.height / 2);
      final double snappedCenterX = (center.dx / step).round() * step;
      final double snappedCenterY = (center.dy / step).round() * step;
      return Offset(
        snappedCenterX - size.width / 2,
        snappedCenterY - size.height / 2,
      );
    } else {
      // OBJECTS: Top-Left corner snaps to the grid lines.
      final double snappedX = (position.dx / step).round() * step;
      final double snappedY = (position.dy / step).round() * step;
      return Offset(snappedX, snappedY);
    }
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

      // ==========================================
      // NEW: ALLOW DOORS TO ATTACH/OVERLAP WALLS
      // ==========================================
      if ((activeEl.type == ElementType.door && other.type == ElementType.wall) ||
          (activeEl.type == ElementType.wall && other.type == ElementType.door)) {
        continue; // Skip collision check for doors vs walls
      }
      // ==========================================

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
          overlap = false; 
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

  // ==========================================
  // COC STYLE BOTTOM ACTION BAR
  // ==========================================
  Widget _buildBottomActionBar() {
    final activeEl = widget.controller.storeLayout.firstWhere(
      (el) => el.id == _activeElementId,
      orElse: () => MapElement(id: '', type: ElementType.wall, position: Offset.zero, label: ''),
    );

    if (activeEl.id.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 5)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildActionMenuButton(
            icon: LucideIcons.rotateCw,
            label: "Rotate",
            color: Colors.blue,
            onTap: () {
              setState(() {
                final double newRot = activeEl.rotation + (math.pi / 2);
                if (!_hasCollision(activeEl, activeEl.position, activeEl.size, newRot)) {
                  activeEl.rotation = newRot;
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Cannot rotate. Overlaps with another element."),
                      backgroundColor: Colors.redAccent,
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              });
            },
          ),
          
          const SizedBox(width: 12),
          Container(width: 1, height: 40, color: Colors.grey.shade700),
          const SizedBox(width: 12),

          if (activeEl.type == ElementType.wall) ...[
            _buildActionMenuButton(
              icon: Icons.linear_scale,
              label: "Select Row",
              color: Colors.orange,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Tip: Just drag the center of the wall to move the entire row!"),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
            ),

            const SizedBox(width: 12),
            Container(width: 1, height: 40, color: Colors.grey.shade700),
            const SizedBox(width: 12),
          ],

          _buildActionMenuButton(
            icon: LucideIcons.trash,
            label: "Remove",
            color: Colors.redAccent,
            onTap: () {
              widget.controller.deleteMapElement(activeEl.id);
              setState(() {
                _activeElementId = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionMenuButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
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
              double scale = math.min(scaleX, scaleY) * 0.9;
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
                onMove: (details) {
                  final RenderBox box = dropContext.findRenderObject() as RenderBox;
                  final Offset localOffset = box.globalToLocal(details.offset);

                  final Size previewSize = _getDefaultSize(details.data);
                  final snappedPos = _snapToGrid(localOffset, previewSize, details.data);

                  final tempEl = MapElement(
                    id: 'temp',
                    type: details.data,
                    position: snappedPos,
                    label: '',
                  );
                  tempEl.size = previewSize;

                  setState(() {
                    _dragPreviewPos = snappedPos;
                    _dragPreviewSize = previewSize;
                    _dragPreviewValid = !_hasCollision(tempEl, snappedPos, previewSize, 0.0);
                    _dragPreviewRotation = 0.0;
                  });
                },
                onLeave: (_) {
                  setState(() {
                    _dragPreviewPos = null;
                    _dragPreviewSize = null;
                  });
                },
                onAcceptWithDetails: (details) {
                  final RenderBox box = dropContext.findRenderObject() as RenderBox;
                  final Offset localOffset = box.globalToLocal(details.offset);

                  final Size finalSize = _getDefaultSize(details.data);
                  final Offset finalPos = _snapToGrid(localOffset, finalSize, details.data);

                  final newEl = MapElement(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    type: details.data,
                    position: finalPos,
                    label: details.data.name.toUpperCase(),
                  );

                  newEl.size = finalSize;

                  if (!_hasCollision(newEl, finalPos, finalSize, 0.0)) {
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

                  setState(() {
                    _dragPreviewPos = null;
                    _dragPreviewSize = null;
                  });
                },
                builder: (context, candidateData, rejectedData) {
                  return GestureDetector(
                    onTap: () {
                      if (widget.mode == MapMode.manage) {
                        setState(() {
                          _activeElementId = null;
                        });
                      } else if (widget.mode == MapMode.view) {
                        setState(() {
                          _selectedPopupElement = null; 
                        });
                      }
                    },
                    child: Transform(
                      alignment: FractionalOffset.center,
                      transform: Matrix4.identity()
                        ..rotateX(-0.95)
                        ..rotateZ(0.785),
                      child: Container(
                        key: _mapKey,
                        width: mapWidth,
                        height: mapHeight,
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 124, 126, 129),
                          border: Border.all(color: Colors.blueGrey, width: 2),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CustomPaint(
                              painter: GridPainter(),
                              size: Size(mapWidth, mapHeight),
                            ),
                            if (_dragPreviewPos != null && _dragPreviewSize != null)
                              Positioned(
                                left: _dragPreviewPos!.dx,
                                top: _dragPreviewPos!.dy,
                                width: _dragPreviewSize!.width,
                                height: _dragPreviewSize!.height,
                                child: IgnorePointer(
                                  // NEW: Rotate the preview box!
                                  child: Transform.rotate(
                                    angle: _dragPreviewRotation,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: _dragPreviewValid
                                            ? Colors.greenAccent.withOpacity(0.4)
                                            : Colors.redAccent.withOpacity(0.5),
                                        border: Border.all(
                                          color: _dragPreviewValid ? Colors.green : Colors.red,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ...sortedLayout.map(
                              (el) => _buildPhysicalElement(el),
                            ),
                            if (_selectedPopupElement != null)
                              _buildFloatingPopup(mapWidth),
                          ],
                        ),
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

    Widget mapDisplay = Stack(
      children: [
        map, 
        
        if (widget.mode == MapMode.manage && _activeElementId != null)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: _buildBottomActionBar(),
            ),
          ),
      ],
    );

    if (widget.mode == MapMode.view) {
      return Container(
        height: 400,
        width: double.infinity,
        color: const Color(0xFF0F172A),
        child: mapDisplay,
      );
    } else {
      return Expanded(
        child: Container(
          width: double.infinity,
          color: const Color(0xFF0F172A),
          child: mapDisplay,
        ),
      );
    }
  }

  Color _getElementColor(ElementType type, bool isHighlighted) {
    switch (type) {
      case ElementType.door:
        return Colors.green;
      case ElementType.rack:
        return Colors.blue;
      case ElementType.shelf:
        return Colors.brown;
      case ElementType.cashier:
        return Colors.purple;
      case ElementType.wall:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildPhysicalElement(MapElement el) {
    final bool isHighlighted = el.id == widget.highlightId;
    final bool isActive =
        el.id == _activeElementId && widget.mode == MapMode.manage;
        
    final bool isWall = el.type == ElementType.wall;
    final bool isHorizontal = isWall ? el.size.width > 20 : false; 
    final bool isVertical = isWall ? el.size.height > 20 : false;
    final double minSize = isWall ? 15.0 : 40.0;
    
    Color baseColor = _getElementColor(el.type, isHighlighted);
    final double modelWidth = el.size.width / 40.0;
    final double modelDepth = el.size.height / 40.0;

    const double mapRotX = 0.95;
    final double mapRotZ = math.pi / 4;

    final double true3DRotationY = el.rotation + mapRotZ;

    CustomPainter? modelPainter;
    double baseY = 0.0;
    double modelHeight = 0.0;
    double footprintScale = 40.0;
    double? footprintCameraDistance;

    double nudgeX = 0.0;
    double nudgeY = 0.0;

    switch (el.type) {
      case ElementType.rack:
        modelPainter = RackPainter(
          rack: Rack3D(width: modelWidth, depth: modelDepth, height: 8.0),
          rotationX: mapRotX,
          rotationY: true3DRotationY,
        );
        baseY = -5.0;
        modelHeight = 8.0;
        footprintScale = 40.0;
        footprintCameraDistance = null;
        nudgeX = -26.0; 
        nudgeY = -3.0;
        break;
      case ElementType.shelf:
        modelPainter = ShelfPainter(
          shelf: Shelf3D(width: modelWidth, depth: modelDepth, height: 7.0),
          rotationX: mapRotX,
          rotationY: true3DRotationY,

        );
        baseY = -3.5;
        modelHeight = 7.0;
        footprintScale = 40.0;
        footprintCameraDistance = null;
        nudgeX = -10.0; 
        nudgeY = -9.0;
        break;
      case ElementType.cashier:
        modelPainter = CashierPainter(
          cashier: Cashier3D(width: modelWidth, depth: modelDepth, height: 3.5),
          rotationX: mapRotX,
          rotationY: true3DRotationY,
        );
        baseY = -2.75;
        modelHeight = 3.5;
        footprintScale = 130.0;
        footprintCameraDistance = null;
        nudgeX = 0; 
        nudgeY = 0;
        break;
      case ElementType.door:
        modelPainter = DoorPainter(
          door: Door3D(width: modelWidth, depth: modelDepth, height: 6.0),
          rotationX: mapRotX,
          rotationY: true3DRotationY,
        );
        baseY = -3.0;
        modelHeight = 6.0;
        footprintScale = 40.0; 
        footprintCameraDistance = null;

        nudgeX = 0; 
        nudgeY = 0;
        break;
      case ElementType.wall:
        modelPainter = WallPainter(
          wall: Wall3D(width: modelWidth, depth: modelDepth, height: 6.0),
          rotationX: mapRotX,
          rotationY: true3DRotationY,
        );
        baseY = -3.0; 
        modelHeight = 6.0;
        footprintScale = 40.0;
        footprintCameraDistance = null;

        nudgeX = 0; 
        nudgeY = 0;
        break;
      default:
        modelPainter = null;
    }

    final bool useFootprintOutline = false;

    Widget shelf = Container(
      width: el.size.width,
      height: el.size.height,
      decoration: BoxDecoration(
        color: modelPainter == null
            ? baseColor.withOpacity(0.3)
            : Colors.transparent,
        border: !useFootprintOutline && isActive
            ? Border.all(color: Colors.yellowAccent, width: 3)
            : (isHighlighted
                  ? Border.all(color: Colors.orange, width: 2)
                  : null),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (modelPainter != null)
            Positioned.fill(
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..rotateZ(-el.rotation)
                  ..rotateZ(-math.pi / 4)
                  ..rotateX(0.20),
                  child: Transform.translate(
                  offset: Offset((-baseY * 12 - 33) + nudgeX, (baseY * 12 - 35) + nudgeY),
                  child: CustomPaint(
                    painter: modelPainter,
                    size: Size(el.size.width, el.size.height),
                  ),
                ),
              ),
            ),
          if (useFootprintOutline && isActive)
            Positioned.fill(
              child: IgnorePointer(
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..rotateZ(-el.rotation)
                    ..rotateZ(-math.pi / 4)
                    ..rotateX(0.95),
                  child: Transform.translate(
                    offset: Offset(0, (-el.size.height * 0.5) + (baseY * 12)),
                    child: Transform.scale(
                      scale: 0.30,
                      child: CustomPaint(
                        painter: FootprintOutlinePainter(
                          width: modelWidth,
                          depth: modelDepth,
                          rotationX: mapRotX,
                          rotationY: true3DRotationY,
                          groundY: baseY,
                          height: modelHeight,
                          scale: footprintScale,
                          cameraDistance: footprintCameraDistance,
                          color: Colors.yellowAccent,
                          strokeWidth: 3,
                        ),
                        size: Size(el.size.width, el.size.height),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
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
                        el.type == ElementType.cashier ||
                        el.type == ElementType.wall) {
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
                      setState(() {});
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
                        el.type == ElementType.cashier ||
                        el.type == ElementType.wall) {
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
                  } else if (widget.mode == MapMode.view) {
                    if (el.type != ElementType.door &&
                        el.type != ElementType.cashier &&
                        el.type != ElementType.wall) {
                      setState(() {
                        if (_selectedPopupElement?.id == el.id) {
                          _selectedPopupElement = null;
                        } else {
                          _selectedPopupElement = el;
                        }
                      });
                    }
                  }
                },
                onPanStart: widget.mode == MapMode.manage
                    ? (details) {
                        _rawDragPosition = el.position;
                      }
                    : null,
                onPanUpdate: widget.mode == MapMode.manage
                    ? (details) {
                        setState(() {
                          _activeElementId = el.id;
                          final double cosR = math.cos(el.rotation);
                          final double sinR = math.sin(el.rotation);

                          final double mapDx =
                              details.delta.dx * cosR - details.delta.dy * sinR;
                          final double mapDy =
                              details.delta.dx * sinR + details.delta.dy * cosR;

                          _rawDragPosition = _rawDragPosition! + Offset(mapDx, mapDy);
                          final Offset snappedPos = _snapToGrid(
                            _rawDragPosition!,
                            el.size,
                            el.type,
                          );

                          final bool isValid = !_hasCollision(
                            el,
                            snappedPos,
                            el.size,
                            el.rotation,
                          );
                          _dragPreviewPos = snappedPos;
                          _dragPreviewSize = el.size;
                          _dragPreviewValid = isValid;
                          _dragPreviewRotation = el.rotation;

                          if (isValid) {
                            el.position = snappedPos;
                          }
                        });
                      }
                    : null,
                onPanEnd: widget.mode == MapMode.manage
                    ? (details) {
                        setState(() {
                          _rawDragPosition = null;
                          _dragPreviewPos = null;
                          _dragPreviewSize = null;
                        });
                      }
                    : null,
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
                          offset: Offset(0, _bounceAnimation.value - 20.0),
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

            // ==========================================
            // 4-WAY SMART STRETCH ARROWS (WALLS ONLY)
            // ==========================================
            if (widget.mode == MapMode.manage && isActive && el.type == ElementType.wall) ...[
              
              // --- 1. LEFT ARROW ---
              if (!isVertical) 
                Positioned(
                  left: -16, 
                  top: (el.size.height / 2) - 12,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        final double localDx = details.delta.dx; 
                        double newWidth = el.size.width - localDx; 
                        if (newWidth < minSize) newWidth = minSize; 

                        final double cosR = math.cos(el.rotation);
                        final double sinR = math.sin(el.rotation);
                        final double appliedDx = el.size.width - newWidth;
                        final Offset newPosition = el.position + Offset(appliedDx * cosR, appliedDx * sinR);

                        if (!_hasCollision(el, newPosition, Size(newWidth, el.size.height), el.rotation)) {
                          el.size = Size(newWidth, el.size.height);
                          el.position = newPosition;
                        }
                      });
                    },
                    child: Container(
    padding: const EdgeInsets.all(12), // Increases the invisible hit area
    color: Colors.transparent, 
    child: _buildArrow(Icons.chevron_left),
  ),
                  ),
                ),

              // --- 2. RIGHT ARROW ---
              if (!isVertical)
                Positioned(
                  right: -16, 
                  top: (el.size.height / 2) - 12,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (details) {
                      setState(() {
                        double newWidth = el.size.width + details.delta.dx;
                        if (newWidth < minSize) newWidth = minSize;

                        if (!_hasCollision(el, el.position, Size(newWidth, el.size.height), el.rotation)) {
                          el.size = Size(newWidth, el.size.height);
                        }
                      });
                    },
                    child: _buildArrow(Icons.chevron_right),
                  ),
                ),

              // --- 3. TOP ARROW ---
              if (!isHorizontal && isWall) 
                Positioned(
                  top: -16, 
                  left: (el.size.width / 2) - 12,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        final double localDy = details.delta.dy; 
                        double newHeight = el.size.height - localDy; 
                        if (newHeight < minSize) newHeight = minSize; 

                        final double cosR = math.cos(el.rotation);
                        final double sinR = math.sin(el.rotation);
                        final double appliedDy = el.size.height - newHeight;
                        
                        final Offset newPosition = el.position + Offset(-appliedDy * sinR, appliedDy * cosR);

                        if (!_hasCollision(el, newPosition, Size(el.size.width, newHeight), el.rotation)) {
                          el.size = Size(el.size.width, newHeight);
                          el.position = newPosition;
                        }
                      });
                    },
                    child: _buildArrow(Icons.expand_less),
                  ),
                ),

              // --- 4. BOTTOM ARROW ---
              if (!isHorizontal && isWall)
                Positioned(
                  bottom: -16, 
                  left: (el.size.width / 2) - 12,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        double newHeight = el.size.height + details.delta.dy;
                        if (newHeight < minSize) newHeight = minSize;

                        if (!_hasCollision(el, el.position, Size(el.size.width, newHeight), el.rotation)) {
                          el.size = Size(el.size.width, newHeight);
                        }
                      });
                    },
                    child: _buildArrow(Icons.expand_more),
                  ),
                ),
            ],

            // ==========================================
            // WIDTH-ONLY STRETCH ARROWS (RACKS, SHELVES, CASHIERS)
            // ==========================================
            if (widget.mode == MapMode.manage && isActive && el.type != ElementType.wall) ...[
              
              // --- LEFT ARROW (Changes Width) ---
              Positioned(
                left: -16, 
                top: (el.size.height / 2) - 12,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      final double localDx = details.delta.dx; 
                      double newWidth = el.size.width - localDx; 
                      if (newWidth < minSize) newWidth = minSize; 

                      final double cosR = math.cos(el.rotation);
                      final double sinR = math.sin(el.rotation);
                      final double appliedDx = el.size.width - newWidth;
                      final Offset newPosition = el.position + Offset(appliedDx * cosR, appliedDx * sinR);

                      if (!_hasCollision(el, newPosition, Size(newWidth, el.size.height), el.rotation)) {
                        el.size = Size(newWidth, el.size.height);
                        el.position = newPosition;
                      }
                    });
                  },
                  child: _buildArrow(Icons.chevron_left),
                ),
              ),

              // --- RIGHT ARROW (Changes Width) ---
              Positioned(
                right: -16, 
                top: (el.size.height / 2) - 12,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      double newWidth = el.size.width + details.delta.dx;
                      if (newWidth < minSize) newWidth = minSize;

                      if (!_hasCollision(el, el.position, Size(newWidth, el.size.height), el.rotation)) {
                        el.size = Size(newWidth, el.size.height);
                      }
                    });
                  },
                  child: _buildArrow(Icons.chevron_right),
                ),
              ),
            ],

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

    double px = el.position.dx + el.size.width + 15;
    double py = el.position.dy - 10;

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
              ),
            ],
            border: Border.all(color: Colors.orange, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        el.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _selectedPopupElement = null),
                      child: const Icon(
                        LucideIcons.x,
                        size: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                child: assignedItems.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Text(
                          "Empty",
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
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
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "SKU: ${item.sku}",
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      "Qty: ${item.quantity}",
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange,
                                      ),
                                    ),
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
      color: const Color(0xFFE5E7EB),
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

  Widget _buildArrow(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.green,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Icon(icon, size: 16, color: Colors.white),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      "This location is currently empty.",
                      style: TextStyle(color: Colors.grey),
                    ),
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
                          title: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            "SKU: ${item.sku} • Lvl: ${item.shelfLevel ?? 'N/A'}",
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "Qty: ${item.quantity} ${item.unit}",
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "₱${item.price.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
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
      ..color = Colors.white
      ..strokeWidth = 1.5;

    const double step = 40;

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

class CADBlockPainter extends CustomPainter {
  final Color baseColor;
  final double zHeight;

  CADBlockPainter({required this.baseColor, this.zHeight = 25.0});

  @override
  void paint(Canvas canvas, Size size) {
    final topColor = baseColor;
    final frontColor = Color.lerp(baseColor, Colors.black, 0.2)!;
    final rightColor = Color.lerp(baseColor, Colors.black, 0.4)!;
    final outlineColor = Colors.black87;

    final double ex = zHeight * 0.4;
    final double ey = -zHeight;

    final double w = size.width - ex;
    final double h = size.height - ey.abs();

    final pBL = Offset(0, size.height);
    final pBR = Offset(w, size.height);
    final pTR = Offset(w, size.height - h);
    final pTL = Offset(0, size.height - h);

    final rBL = pBL + Offset(ex, ey);
    final rBR = pBR + Offset(ex, ey);
    final rTR = pTR + Offset(ex, ey);
    final rTL = pTL + Offset(ex, ey);

    final fillPaint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = outlineColor;

    void drawFace(List<Offset> points, Color color) {
      final path = Path()..addPolygon(points, true);
      fillPaint.color = color;
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, strokePaint);
    }

    drawFace([pBR, pTR, rTR, rBR], rightColor);
    drawFace([pBL, pBR, rBR, rBL], frontColor);
    drawFace([rBL, rBR, rTR, rTL], topColor);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}