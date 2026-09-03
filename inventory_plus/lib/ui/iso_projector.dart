import 'dart:math' as math;
import 'dart:ui';

class IsoProjector {
  static const double rotX = -0.7; // The tilt of the floor
  static const double rotZ = 0.7;  // The isometric spin
  static const double scale = 40.0; // The unified scale ratio

  // Projects a 3D coordinate (x, y, z) directly onto your 2D screen
  static Offset project(double x, double y, double z, Offset origin) {
    final cosZ = math.cos(rotZ), sinZ = math.sin(rotZ);
    final x1 = x * cosZ - y * sinZ;
    final y1 = x * sinZ + y * cosZ;

    final cosX = math.cos(rotX), sinX = math.sin(rotX);
    final y2 = y1 * cosX - z * sinX;

    return origin + Offset(x1 * scale, y2 * scale);
  }
}