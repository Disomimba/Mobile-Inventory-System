import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/inventory.dart';

/// Snaps furniture to the grid, or to a nearby wall face when the grid would
/// leave it slightly inside the wall. Walls keep their center-based grid snap.
Offset snapMapPosition(
  Offset position,
  Size size,
  ElementType type,
  Iterable<MapElement> layout, {
  double rotation = 0,
}) {
  const step = 40.0;
  if (type == ElementType.wall) {
    final center = position + Offset(size.width / 2, size.height / 2);
    return Offset(
      (center.dx / step).round() * step - size.width / 2,
      (center.dy / step).round() * step - size.height / 2,
    );
  }

  final gridPosition = Offset(
    (position.dx / step).round() * step,
    (position.dy / step).round() * step,
  );
  if (type == ElementType.door) return gridPosition;

  // Use the visible footprint for a rotated rack, shelf, or counter.
  final cosR = math.cos(rotation).abs();
  final sinR = math.sin(rotation).abs();
  final footprintWidth = size.width * cosR + size.height * sinR;
  final footprintHeight = size.width * sinR + size.height * cosR;
  final leftInset = (size.width - footprintWidth) / 2;
  final topInset = (size.height - footprintHeight) / 2;
  final rawLeft = position.dx + leftInset;
  final rawRight = rawLeft + footprintWidth;
  final rawTop = position.dy + topInset;
  final rawBottom = rawTop + footprintHeight;

  var snappedX = gridPosition.dx;
  var snappedY = gridPosition.dy;
  var nearestX = step / 2;
  var nearestY = step / 2;

  for (final wall in layout.where(
    (element) => element.type == ElementType.wall,
  )) {
    final wallRect = wall.position & wall.size;
    final vertical = wall.size.height > wall.size.width;
    final horizontal = wall.size.width > wall.size.height;

    if (vertical &&
        snappedY + topInset < wallRect.bottom &&
        snappedY + topInset + footprintHeight > wallRect.top) {
      final rightDistance = (rawLeft - wallRect.right).abs();
      if (rightDistance < nearestX) {
        nearestX = rightDistance;
        snappedX = wallRect.right - leftInset;
      }
      final leftDistance = (rawRight - wallRect.left).abs();
      if (leftDistance < nearestX) {
        nearestX = leftDistance;
        snappedX = wallRect.left - footprintWidth - leftInset;
      }
    }

    if (horizontal &&
        snappedX + leftInset < wallRect.right &&
        snappedX + leftInset + footprintWidth > wallRect.left) {
      final bottomDistance = (rawTop - wallRect.bottom).abs();
      if (bottomDistance < nearestY) {
        nearestY = bottomDistance;
        snappedY = wallRect.bottom - topInset;
      }
      final topDistance = (rawBottom - wallRect.top).abs();
      if (topDistance < nearestY) {
        nearestY = topDistance;
        snappedY = wallRect.top - footprintHeight - topInset;
      }
    }
  }

  return Offset(snappedX, snappedY);
}
