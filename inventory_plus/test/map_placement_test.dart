import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_plus/data/inventory.dart';
import 'package:inventory_plus/logic/map_placement.dart';

void main() {
  final walls = [
    MapElement(
      id: 'left-wall',
      type: ElementType.wall,
      position: const Offset(-7.5, -7.5),
      size: const Size(15, 200),
    ),
    MapElement(
      id: 'top-wall',
      type: ElementType.wall,
      position: const Offset(-7.5, -7.5),
      size: const Size(200, 15),
    ),
  ];

  test('shelf can sit against two wall faces without overlapping either', () {
    final position = snapMapPosition(
      const Offset(12, 12),
      const Size(104, 48),
      ElementType.shelf,
      walls,
    );

    expect(position, const Offset(7.5, 7.5));
    final shelf = position & const Size(104, 48);
    for (final wall in walls) {
      expect(shelf.overlaps(wall.position & wall.size), isFalse);
    }
  });

  test('furniture away from a wall keeps its grid snap', () {
    expect(
      snapMapPosition(
        const Offset(42, 41),
        const Size(104, 48),
        ElementType.shelf,
        walls,
      ),
      const Offset(40, 40),
    );
  });

  test('rotated furniture uses its visible footprint at the wall', () {
    final position = snapMapPosition(
      const Offset(-15, 30),
      const Size(104, 48),
      ElementType.shelf,
      walls,
      rotation: math.pi / 2,
    );

    // A quarter turn makes the 48-unit side face the vertical wall.
    expect(position.dx, closeTo(-20.5, 0.000001));
    expect(position.dy, closeTo(35.5, 0.000001));
  });
}
