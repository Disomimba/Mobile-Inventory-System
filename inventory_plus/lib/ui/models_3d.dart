import 'dart:math' as math;
import 'package:flutter/material.dart';

// ============================================================================
// SHARED 3D PRIMITIVES
// ============================================================================

class Point3D {
  final double x;
  final double y;
  final double z;

  const Point3D(this.x, this.y, this.z);
}

class Face3D {
  final List<Point3D> points;
  final Color color;

  const Face3D(this.points, this.color);
}

List<Face3D> createBox({
  required double x,
  required double y,
  required double z,
  required double width,
  required double height,
  required double depth,
  required Color color,
}) {
  final x1 = x - width / 2;
  final x2 = x + width / 2;
  final y1 = y - height / 2;
  final y2 = y + height / 2;
  final z1 = z - depth / 2;
  final z2 = z + depth / 2;

  final p000 = Point3D(x1, y1, z1);
  final p100 = Point3D(x2, y1, z1);
  final p110 = Point3D(x2, y2, z1);
  final p010 = Point3D(x1, y2, z1);

  final p001 = Point3D(x1, y1, z2);
  final p101 = Point3D(x2, y1, z2);
  final p111 = Point3D(x2, y2, z2);
  final p011 = Point3D(x1, y2, z2);

  return [
    Face3D([p001, p101, p111, p011], color), // Front
    Face3D([p100, p000, p010, p110], color.withOpacity(0.65)), // Back
    Face3D([p000, p001, p011, p010], color.withOpacity(0.75)), // Left
    Face3D([p101, p100, p110, p111], color.withOpacity(0.85)), // Right
    Face3D([p011, p111, p110, p010], color.withOpacity(0.9)), // Top
    Face3D([p000, p100, p101, p001], color.withOpacity(0.55)), // Bottom
  ];
}

// ============================================================================
// FOOTPRINT OUTLINE PAINTER (for selection highlight)
// ============================================================================
// Draws just the projected floor rectangle (the 4 bottom corners) of a 3D
// model, using the exact same rotate/project math as the model painters.
// This lets a selection border sit exactly under an object's "feet"
// instead of drawing a plain axis-aligned rectangle around the widget box.
class FootprintOutlinePainter extends CustomPainter {
  final double width;
  final double depth;
  final double rotationX;
  final double rotationY;
  final Color color;
  final double strokeWidth;

  /// The model's actual ground level in its own local Y coordinate space
  /// (i.e. the same `baseY` used to sit the model on the floor). This is
  /// NOT always 0 — e.g. the cashier's lowest geometry is around y=-2.75.
  final double groundY;

  /// The model's real height (top = groundY + height). Used to draw the
  /// full bounding-box silhouette (top face + visible vertical edges),
  /// not just a flat floor rectangle.
  final double height;

  /// If null, uses a flat (non-perspective) projection with [scale]
  /// (matches RackPainter/ShelfPainter). If provided, uses the same
  /// perspective projection as CashierPainter/DoorPainter.
  final double? cameraDistance;
  final double scale;

  FootprintOutlinePainter({
    required this.width,
    required this.depth,
    required this.rotationX,
    required this.rotationY,
    this.groundY = 0,
    this.height = 0,
    this.cameraDistance,
    this.scale = 40.0,
    this.color = Colors.yellowAccent,
    this.strokeWidth = 3,
  });

  Point3D rotate(Point3D p) {
    final cosY = math.cos(rotationY);
    final sinY = math.sin(rotationY);
    final x1 = p.x * cosY - p.z * sinY;
    final z1 = p.x * sinY + p.z * cosY;

    final cosX = math.cos(rotationX);
    final sinX = math.sin(rotationX);
    final y2 = p.y * cosX - z1 * sinX;
    final z2 = p.y * sinX + z1 * cosX;

    return Point3D(x1, y2, z2);
  }

  Offset project(Point3D p, Size size) {
    if (cameraDistance != null) {
      final perspective = cameraDistance! / (cameraDistance! - p.z);
      return Offset(
        size.width / 2 + p.x * scale * perspective,
        size.height / 2 - p.y * scale * perspective,
      );
    }
    return Offset(size.width / 2 + p.x * scale, size.height / 2 - p.y * scale);
  }

  // Standard monotone-chain convex hull. For a rotated cuboid's 8
  // projected corners this hull IS the true silhouette: the top face
  // outline plus whichever bottom corners stick out past it — which is
  // exactly the "top diamond + two side drops to the floor" look.
  List<Offset> _convexHull(List<Offset> pts) {
    if (pts.length < 3) return pts;
    final sorted = List<Offset>.from(pts)
      ..sort((a, b) =>
          a.dx != b.dx ? a.dx.compareTo(b.dx) : a.dy.compareTo(b.dy));

    double cross(Offset o, Offset a, Offset b) =>
        (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);

    final lower = <Offset>[];
    for (final p in sorted) {
      while (lower.length >= 2 &&
          cross(lower[lower.length - 2], lower[lower.length - 1], p) <= 0) {
        lower.removeLast();
      }
      lower.add(p);
    }

    final upper = <Offset>[];
    for (final p in sorted.reversed) {
      while (upper.length >= 2 &&
          cross(upper[upper.length - 2], upper[upper.length - 1], p) <= 0) {
        upper.removeLast();
      }
      upper.add(p);
    }

    lower.removeLast();
    upper.removeLast();
    return [...lower, ...upper];
  }

  @override
  void paint(Canvas canvas, Size size) {
    // We only need the 4 bottom corners at ground level
    final corners = [
      Point3D(-width / 2, groundY, -depth / 2),
      Point3D(width / 2, groundY, -depth / 2),
      Point3D(width / 2, groundY, depth / 2),
      Point3D(-width / 2, groundY, depth / 2),
    ];

    // Project the 3D points to 2D
    final projected = corners.map((c) => project(rotate(c), size)).toList();
    if (projected.isEmpty) return;

    // Draw a simple path connecting the 4 floor corners
    final path = Path()..moveTo(projected[0].dx, projected[0].dy);
    for (int i = 1; i < projected.length; i++) {
      path.lineTo(projected[i].dx, projected[i].dy);
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant FootprintOutlinePainter oldDelegate) {
    return oldDelegate.width != width ||
        oldDelegate.depth != depth ||
        oldDelegate.rotationX != rotationX ||
        oldDelegate.rotationY != rotationY ||
        oldDelegate.groundY != groundY ||
        oldDelegate.height != height ||
        oldDelegate.cameraDistance != cameraDistance ||
        oldDelegate.scale != scale ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

// ============================================================================
// RACK 3D MODEL & PAINTER
// ============================================================================

class Rack3D {
  final double width;
  final double height;
  final double depth;

  const Rack3D({this.width = 3.0, this.height = 4.0, this.depth = 1.5});

  List<Face3D> build() {
    final faces = <Face3D>[];
    const postThickness = 0.15;
    const shelfThickness = 0.10;
    final postColor = const Color(0xff37474F);
    final shelfColor = const Color(0xff90A4AE);

    // 4 VERTICAL POSTS
    faces.addAll(createBox(x: -width / 2 + postThickness / 2, y: 0, z: -depth / 2 + postThickness / 2, width: postThickness, height: height, depth: postThickness, color: postColor));
    faces.addAll(createBox(x: width / 2 - postThickness / 2, y: 0, z: -depth / 2 + postThickness / 2, width: postThickness, height: height, depth: postThickness, color: postColor));
    faces.addAll(createBox(x: -width / 2 + postThickness / 2, y: 0, z: depth / 2 - postThickness / 2, width: postThickness, height: height, depth: postThickness, color: postColor));
    faces.addAll(createBox(x: width / 2 - postThickness / 2, y: 0, z: depth / 2 - postThickness / 2, width: postThickness, height: height, depth: postThickness, color: postColor));

    // 4 HORIZONTAL SHELVES
    const int numShelves = 4;
    for (int i = 0; i < numShelves; i++) {
      double yPos = -height / 2 + (height / (numShelves - 1)) * i;
      faces.addAll(createBox(x: 0, y: yPos, z: 0, width: width, height: shelfThickness, depth: depth, color: shelfColor));
    }
    return faces;
  }
}

class RackPainter extends CustomPainter {
  final Rack3D rack;
  final double rotationY;
  final double rotationX;

  RackPainter({required this.rack, required this.rotationY, required this.rotationX});

  Point3D rotate(Point3D p) {
    final cosY = math.cos(rotationY);
    final sinY = math.sin(rotationY);
    final x1 = p.x * cosY - p.z * sinY;
    final z1 = p.x * sinY + p.z * cosY;

    final cosX = math.cos(rotationX);
    final sinX = math.sin(rotationX);
    final y2 = p.y * cosX - z1 * sinX;
    final z2 = p.y * sinX + z1 * cosX;

    return Point3D(x1, y2, z2);
  }

  // Offset project(Point3D p, Size size) {
  //   const cameraDistance = 10.0;
  //   const scale = 140.0;
  //   final perspective = cameraDistance / (cameraDistance - p.z);
  //   return Offset(size.width / 2 + p.x * scale * perspective, size.height / 2 - p.y * scale * perspective);
  // }
  Offset project(Point3D p, Size size) {
  // You may need to tweak the scale value slightly (e.g., 140.0 or 150.0) 
  // depending on the size of your base element.
  const scale = 40.0; 
  
  // Notice we removed the perspective division calculation entirely
  return Offset(
    size.width / 2 + p.x * scale, 
    size.height / 2 - p.y * scale
  );
}
  @override
  void paint(Canvas canvas, Size size) {
    final faces = rack.build();
    faces.sort((a, b) {
      double avgA = a.points.map((p) => rotate(p).z).reduce((v, e) => v + e) / a.points.length;
      double avgB = b.points.map((p) => rotate(p).z).reduce((v, e) => v + e) / b.points.length;
      return avgA.compareTo(avgB);
    });

    for (final face in faces) {
      final path = Path();
      final first = project(rotate(face.points.first), size);
      path.moveTo(first.dx, first.dy);
      for (int i = 1; i < face.points.length; i++) {
        final point = project(rotate(face.points[i]), size);
        path.lineTo(point.dx, point.dy);
      }
      path.close();

      canvas.drawPath(path, Paint()..style = PaintingStyle.fill..color = face.color);
      canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.0..color = Colors.black.withOpacity(0.5));
    }
  }

  @override
  bool shouldRepaint(covariant RackPainter oldDelegate) => true;
}

// ============================================================================
// SHELF 3D MODEL & PAINTER
// ============================================================================

class Shelf3D {
  final double width;
  final double height;
  final double depth;

  const Shelf3D({this.width = 2.6, this.height = 4.2, this.depth = 1.2});

  List<Face3D> build() {
    final faces = <Face3D>[];
    const thick = 0.15;
    final exteriorColor = const Color(0xff5D4037);
    final interiorColor = const Color(0xff795548);
    final backColor = const Color(0xff4E342E);

    faces.addAll(createBox(x: -width / 2 + thick / 2, y: 0, z: 0, width: thick, height: height, depth: depth, color: exteriorColor));
    faces.addAll(createBox(x: width / 2 - thick / 2, y: 0, z: 0, width: thick, height: height, depth: depth, color: exteriorColor));

    final innerWidth = width - (thick * 2);
    faces.addAll(createBox(x: 0, y: -height / 2 + thick / 2, z: 0, width: innerWidth, height: thick, depth: depth, color: exteriorColor));
    faces.addAll(createBox(x: 0, y: height / 2 - thick / 2, z: 0, width: innerWidth, height: thick, depth: depth, color: exteriorColor));

    const backThick = 0.05;
    faces.addAll(createBox(x: 0, y: 0, z: -depth / 2 + backThick / 2, width: innerWidth, height: height - (thick * 2), depth: backThick, color: backColor));

    const int numInnerShelves = 3;
    final spacing = (height - (thick * 2)) / (numInnerShelves + 1);
    for (int i = 1; i <= numInnerShelves; i++) {
      faces.addAll(createBox(x: 0, y: -height / 2 + thick + (spacing * i) - (thick / 2), z: backThick / 2, width: innerWidth, height: thick, depth: depth - backThick, color: interiorColor));
    }
    return faces;
  }
}

class ShelfPainter extends CustomPainter {
  final Shelf3D shelf;
  final double rotationY;
  final double rotationX;

  ShelfPainter({required this.shelf, required this.rotationY, required this.rotationX});

  Point3D rotate(Point3D p) {
    final cosY = math.cos(rotationY);
    final sinY = math.sin(rotationY);
    final x1 = p.x * cosY - p.z * sinY;
    final z1 = p.x * sinY + p.z * cosY;

    final cosX = math.cos(rotationX);
    final sinX = math.sin(rotationX);
    final y2 = p.y * cosX - z1 * sinX;
    final z2 = p.y * sinX + z1 * cosX;

    return Point3D(x1, y2, z2);
  }

  Offset project(Point3D p, Size size) {
    // Flat/orthographic, matching Rack/Cashier/Door and the floor grid.
    // This was the last remaining perspective source in the model
    // painters — it had its own vanishing point (cameraDistance: 11.0)
    // that didn't match anything else on the board.
    const scale = 40.0;
    return Offset(size.width / 2 + p.x * scale, size.height / 2 - p.y * scale);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final faces = shelf.build();
    faces.sort((a, b) {
      double avgA = a.points.map((p) => rotate(p).z).reduce((v, e) => v + e) / a.points.length;
      double avgB = b.points.map((p) => rotate(p).z).reduce((v, e) => v + e) / b.points.length;
      return avgA.compareTo(avgB);
    });

    for (final face in faces) {
      final path = Path();
      final first = project(rotate(face.points.first), size);
      path.moveTo(first.dx, first.dy);
      for (int i = 1; i < face.points.length; i++) {
        final point = project(rotate(face.points[i]), size);
        path.lineTo(point.dx, point.dy);
      }
      path.close();

      canvas.drawPath(path, Paint()..style = PaintingStyle.fill..color = face.color);
      canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.0..color = Colors.black.withOpacity(0.6));
    }
  }

  @override
  bool shouldRepaint(covariant ShelfPainter oldDelegate) => true;
}

// ============================================================================
// CASHIER 3D MODEL & PAINTER
// ============================================================================

class Cashier3D {
  final double width;
  final double height;
  final double depth;
  // Added constructor properties to make it match the pattern and be stretchable!
  const Cashier3D({this.width = 4.2, this.height = 2.0, this.depth = 1.6});

  List<Face3D> build() {
    final faces = <Face3D>[];
    final baseColor = const Color(0xffECEFF1);
    final topColor = const Color(0xff37474F);
    final deviceColor = const Color(0xff212121);
    final screenColor = const Color(0xff64B5F6);
    final customerScreen = const Color(0xff81C784);
    final scannerColor = const Color(0xffB0BEC5);
    final glassColor = const Color(0xffE0F7FA);

faces.addAll(createBox(
  x: 0,
  y: -1.375,
  z: 0,
  width: width,
  height: 2.75,
  depth: depth,
  color: baseColor,
));
    // 2. COUNTERTOP
    faces.addAll(createBox(x: 0, y: 0.1, z: 0, width: width + 0.2, height: 0.2, depth: depth + 0.2, color: topColor));

    // Devices remain relatively fixed on the counter
    double leftSide = -(width / 4);
    double rightSide = (width / 4);

    // 3. SCANNER
    faces.addAll(createBox(x: leftSide, y: 0.22, z: 0, width: 1.4, height: 0.05, depth: 1.2, color: scannerColor));
    faces.addAll(createBox(x: leftSide, y: 0.25, z: 0, width: 1.0, height: 0.02, depth: 0.8, color: glassColor));

    // 4. CASH REGISTER
    faces.addAll(createBox(x: rightSide, y: 0.4, z: 0, width: 0.3, height: 0.4, depth: 0.3, color: deviceColor));
    faces.addAll(createBox(x: rightSide, y: 0.8, z: 0, width: 1.2, height: 0.8, depth: 0.15, color: deviceColor));
    faces.addAll(createBox(x: rightSide, y: 0.8, z: 0.08, width: 1.0, height: 0.65, depth: 0.05, color: screenColor));
    faces.addAll(createBox(x: rightSide, y: 0.85, z: -0.08, width: 0.8, height: 0.4, depth: 0.05, color: customerScreen));
    faces.addAll(createBox(x: rightSide, y: 0.26, z: 0.5, width: 1.1, height: 0.1, depth: 0.6, color: deviceColor));

    return faces;
  }
}

class CashierPainter extends CustomPainter {
  final Cashier3D cashier;
  final double rotationY;
  final double rotationX;

  CashierPainter({required this.cashier, required this.rotationY, required this.rotationX});

  Point3D rotate(Point3D p) {
    final cosY = math.cos(rotationY);
    final sinY = math.sin(rotationY);
    final x1 = p.x * cosY - p.z * sinY;
    final z1 = p.x * sinY + p.z * cosY;

    final cosX = math.cos(rotationX);
    final sinX = math.sin(rotationX);
    final y2 = p.y * cosX - z1 * sinX;
    final z2 = p.y * sinX + z1 * cosX;

    return Point3D(x1, y2, z2);
  }

  Offset project(Point3D p, Size size) {
    // Flat/orthographic, matching Rack/Shelf — keeps every object's top
    // edges parallel to the grid instead of warping with depth.
    const scale = 40.0;
    return Offset(size.width / 2 + p.x * scale, size.height / 2 - p.y * scale);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final faces = cashier.build();
    faces.sort((a, b) {
      double avgA = a.points.map((p) => rotate(p).z).reduce((v, e) => v + e) / a.points.length;
      double avgB = b.points.map((p) => rotate(p).z).reduce((v, e) => v + e) / b.points.length;
      return avgA.compareTo(avgB);
    });

    for (final face in faces) {
      final path = Path();
      final first = project(rotate(face.points.first), size);
      path.moveTo(first.dx, first.dy);
      for (int i = 1; i < face.points.length; i++) {
        final point = project(rotate(face.points[i]), size);
        path.lineTo(point.dx, point.dy);
      }
      path.close();

      canvas.drawPath(path, Paint()..style = PaintingStyle.fill..color = face.color);
      canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.0..color = Colors.black.withOpacity(0.5));
    }
  }

  @override
  bool shouldRepaint(covariant CashierPainter oldDelegate) => true;
}

// ============================================================================
// DOOR 3D MODEL & PAINTER
// ============================================================================

class Door3D {
  final double width;
  final double height;
  final double depth;

  const Door3D({this.width = 2.0, this.height = 3.5, this.depth = 0.25});

  List<Face3D> build() {
    final faces = <Face3D>[];
    const frame = 0.22;

    // FRAMES
    faces.addAll(createBox(x: -width / 2 + frame / 2, y: height / 2, z: 0, width: frame, height: height, depth: depth, color: const Color(0xff6D4C41)));
    faces.addAll(createBox(x: width / 2 - frame / 2, y: height / 2, z: 0, width: frame, height: height, depth: depth, color: const Color(0xff6D4C41)));
    faces.addAll(createBox(x: 0, y: height - frame / 2, z: 0, width: width, height: frame, depth: depth, color: const Color(0xff6D4C41)));

    // PANELS
    faces.addAll(createBox(x: 0, y: height / 2 - 0.05, z: -0.01, width: width - frame * 2, height: height - frame, depth: depth * 0.7, color: const Color(0xffA1887F)));
    faces.addAll(createBox(x: 0, y: height / 2, z: depth * 0.4, width: width - frame * 2.4, height: height - frame * 1.6, depth: 0.05, color: const Color(0xff8D6E63)));

    return faces;
  }
}

class DoorPainter extends CustomPainter {
  final Door3D door;
  final double rotationY;
  final double rotationX;

  DoorPainter({required this.door, required this.rotationY, required this.rotationX});

  Point3D rotate(Point3D p) {
    final cosY = math.cos(rotationY);
    final sinY = math.sin(rotationY);
    final x1 = p.x * cosY - p.z * sinY;
    final z1 = p.x * sinY + p.z * cosY;

    final cosX = math.cos(rotationX);
    final sinX = math.sin(rotationX);
    final y2 = p.y * cosX - z1 * sinX;
    final z2 = p.y * sinX + z1 * cosX;

    return Point3D(x1, y2, z2);
  }

  Offset project(Point3D p, Size size) {
    // Flat/orthographic, matching Rack/Shelf — keeps every object's top
    // edges parallel to the grid instead of warping with depth.
    const scale = 180.0;
    return Offset(size.width / 2 + p.x * scale, size.height / 2 - p.y * scale);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final faces = door.build();
    faces.sort((a, b) {
      double avgA = a.points.map((p) => rotate(p).z).reduce((v, e) => v + e) / a.points.length;
      double avgB = b.points.map((p) => rotate(p).z).reduce((v, e) => v + e) / b.points.length;
      return avgA.compareTo(avgB);
    });

    for (final face in faces) {
      final path = Path();
      final first = project(rotate(face.points.first), size);
      path.moveTo(first.dx, first.dy);
      for (int i = 1; i < face.points.length; i++) {
        final point = project(rotate(face.points[i]), size);
        path.lineTo(point.dx, point.dy);
      }
      path.close();

      canvas.drawPath(path, Paint()..style = PaintingStyle.fill..color = face.color);
      canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = Colors.black.withOpacity(0.7));
    }

    // HANDLE
    final facingFront = rotate(const Point3D(0, 0, 1)).z > 0;
    final handleZ = facingFront ? (door.depth * 0.6) : (-door.depth * 0.6);
    final handle = rotate(Point3D(door.width * 0.27, door.height * 0.48, handleZ));
    final handlePosition = project(handle, size);

    canvas.drawCircle(handlePosition, 9, Paint()..color = const Color(0xffD6B36A)..style = PaintingStyle.fill);
    canvas.drawCircle(handlePosition, 9, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant DoorPainter oldDelegate) => true;
}

// ============================================================================
// WALL 3D MODEL & PAINTER
// ============================================================================

class Wall3D {
  final double width;
  final double height;
  final double depth;

  const Wall3D({this.width = 4.0, this.height = 6.0, this.depth = 0.5});

  List<Face3D> build() {
    return createBox(
      x: 0,
      y: 0,
      z: 0,
      width: width,
      height: height,
      depth: depth,
      color: const Color(0xff9E9E9E), // Neutral grey base for walls
    );
  }
}

class WallPainter extends CustomPainter {
  final Wall3D wall;
  final double rotationY;
  final double rotationX;

  WallPainter({required this.wall, required this.rotationY, required this.rotationX});

  Point3D rotate(Point3D p) {
    final cosY = math.cos(rotationY);
    final sinY = math.sin(rotationY);
    final x1 = p.x * cosY - p.z * sinY;
    final z1 = p.x * sinY + p.z * cosY;

    final cosX = math.cos(rotationX);
    final sinX = math.sin(rotationX);
    final y2 = p.y * cosX - z1 * sinX;
    final z2 = p.y * sinX + z1 * cosX;

    return Point3D(x1, y2, z2);
  }

  Offset project(Point3D p, Size size) {
    const scale = 40.0;
    return Offset(size.width / 2 + p.x * scale, size.height / 2 - p.y * scale);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final faces = wall.build();
    faces.sort((a, b) {
      double avgA = a.points.map((p) => rotate(p).z).reduce((v, e) => v + e) / a.points.length;
      double avgB = b.points.map((p) => rotate(p).z).reduce((v, e) => v + e) / b.points.length;
      return avgA.compareTo(avgB);
    });

    for (final face in faces) {
      final path = Path();
      final first = project(rotate(face.points.first), size);
      path.moveTo(first.dx, first.dy);
      for (int i = 1; i < face.points.length; i++) {
        final point = project(rotate(face.points[i]), size);
        path.lineTo(point.dx, point.dy);
      }
      path.close();

      canvas.drawPath(path, Paint()..style = PaintingStyle.fill..color = face.color);
      canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.0..color = Colors.black.withOpacity(0.5));
    }
  }

  @override
  bool shouldRepaint(covariant WallPainter oldDelegate) => true;
}