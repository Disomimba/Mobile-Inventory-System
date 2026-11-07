import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_plus/data/inventory.dart';
import 'package:inventory_plus/logic/inventory_controller.dart';
import 'package:inventory_plus/ui/store_map.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-publishable-key',
    );
  });

  testWidgets('tapping the raised cashier model selects it', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cashier = MapElement(
      id: 'cashier',
      type: ElementType.cashier,
      position: const Offset(400, 400),
      size: const Size(168, 64),
    );
    MapElement? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StoreMap(
            controller: InventoryController(),
            layout: [cashier],
            mode: MapMode.manage,
            viewStyle: MapViewStyle.threeD,
            showMobileToolbar: false,
            onManageSelectionChanged: (element) => selected = element,
          ),
        ),
      ),
    );
    await tester.pump();

    final hitSurface = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint &&
          widget.painter.runtimeType.toString() == '_MapObjectHitPainter',
    );
    expect(hitSurface, findsOneWidget);
    final widget = tester.widget<CustomPaint>(hitSurface);
    final box = tester.renderObject<RenderBox>(hitSurface);
    expect(widget.painter?.hitTest(Offset.zero), isFalse);
    Offset? raisedPoint;
    for (var y = 0.0; y < 180 && raisedPoint == null; y += 5) {
      for (var x = 0.0; x < box.size.width; x += 5) {
        final point = Offset(x, y);
        if (widget.painter?.hitTest(point) == true) {
          raisedPoint = point;
          break;
        }
      }
    }
    expect(raisedPoint, isNotNull);

    final visualPoint = box.localToGlobal(raisedPoint!);
    final hoverOutline = find.byKey(const ValueKey('map-hover-glow-cashier'));
    expect(hoverOutline, findsNothing);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(1, 1));
    await mouse.moveTo(visualPoint);
    await tester.pump();
    expect(hoverOutline, findsOneWidget);
    final mapState = tester.state<StoreMapState>(find.byType(StoreMap));
    mapState.setPaletteDragActive(true);
    await tester.pump();
    expect(hoverOutline, findsNothing);
    await mouse.moveTo(const Offset(1, 1));
    await mouse.moveTo(visualPoint);
    await tester.pump();
    expect(hoverOutline, findsNothing);
    mapState.setPaletteDragActive(false);
    await mouse.moveTo(const Offset(1, 1));
    await mouse.moveTo(visualPoint);
    await tester.pump();
    expect(hoverOutline, findsOneWidget);
    await mouse.moveTo(const Offset(1, 1));
    await tester.pump();
    expect(hoverOutline, findsNothing);

    await tester.tapAt(visualPoint);
    await tester.pump();
    expect(selected?.id, 'cashier');

    mapState.applySidebarAction(MapSidebarAction.widthRightPlus);
    expect(cashier.size.width, 208);
    expect(cashier.position, const Offset(400, 400));
    mapState.applySidebarAction(MapSidebarAction.widthRightMinus);
    expect(cashier.position, const Offset(400, 400));

    mapState.applySidebarAction(MapSidebarAction.rotate);
    mapState.applySidebarAction(MapSidebarAction.widthRightPlus);
    expect(cashier.size.width, 208);
    expect(cashier.position.dx, closeTo(380, 0.001));
    expect(cashier.position.dy, closeTo(420, 0.001));
    mapState.applySidebarAction(MapSidebarAction.widthRightMinus);
    expect(cashier.position.dx, closeTo(400, 0.001));
    expect(cashier.position.dy, closeTo(400, 0.001));

    mapState.applySidebarAction(MapSidebarAction.rotate);
    mapState.applySidebarAction(MapSidebarAction.widthRightPlus);
    expect(cashier.size.width, 208);
    expect(cashier.position.dx, closeTo(360, 0.001));
    expect(cashier.position.dy, closeTo(400, 0.001));
    mapState.applySidebarAction(MapSidebarAction.widthRightMinus);
    expect(cashier.position.dx, closeTo(400, 0.001));
    mapState.applySidebarAction(MapSidebarAction.widthLeftPlus);
    expect(cashier.size.width, 208);
    expect(cashier.position.dx, closeTo(400, 0.001));
    mapState.applySidebarAction(MapSidebarAction.widthLeftMinus);
    expect(cashier.position.dx, closeTo(400, 0.001));
    expect(cashier.size.width, 168);
  });

  testWidgets('hiding walls leaves other objects and the layout intact', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final wall = MapElement(
      id: 'wall',
      type: ElementType.wall,
      position: const Offset(300, 300),
      size: const Size(320, 15),
    );
    final cashier = MapElement(
      id: 'cashier',
      type: ElementType.cashier,
      position: const Offset(400, 400),
      size: const Size(168, 64),
    );
    final layout = [wall, cashier];
    final controller = InventoryController();
    var hideWalls = false;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Stack(
              children: [
                StoreMap(
                  controller: controller,
                  layout: layout,
                  mode: MapMode.manage,
                  viewStyle: MapViewStyle.threeD,
                  hideWalls: hideWalls,
                  showMobileToolbar: false,
                ),
                TextButton(
                  onPressed: () => setState(() => hideWalls = !hideWalls),
                  child: const Text('Toggle walls'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('wall')), findsOneWidget);
    expect(find.byKey(const ValueKey('cashier')), findsOneWidget);

    await tester.tap(find.text('Toggle walls'));
    await tester.pump();
    expect(find.byKey(const ValueKey('wall')), findsNothing);
    expect(find.byKey(const ValueKey('cashier')), findsOneWidget);
    expect(layout, [wall, cashier]);

    await tester.tap(find.text('Toggle walls'));
    await tester.pump();
    expect(find.byKey(const ValueKey('wall')), findsOneWidget);
  });

  testWidgets('floor expands to include a rotated cashier footprint', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = InventoryController();
    Widget mapAtRotation(double rotation) => MaterialApp(
      home: Scaffold(
        body: StoreMap(
          controller: controller,
          layout: [
            MapElement(
              id: 'cashier',
              type: ElementType.cashier,
              position: const Offset(400, 400),
              size: const Size(168, 64),
              rotation: rotation,
            ),
          ],
          mode: MapMode.manage,
          viewStyle: MapViewStyle.threeD,
          showMobileToolbar: false,
        ),
      ),
    );

    final floor = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is GridPainter,
    );
    await tester.pumpWidget(mapAtRotation(0));
    final before = tester.widget<CustomPaint>(floor).size!;
    await tester.pumpWidget(mapAtRotation(math.pi / 2));
    final after = tester.widget<CustomPaint>(floor).size!;
    expect(after.height, greaterThan(before.height));
  });

  testWidgets('rotation into a wall is rejected', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cashier = MapElement(
      id: 'cashier',
      type: ElementType.cashier,
      position: const Offset(400, 400),
      size: const Size(168, 64),
    );
    final wall = MapElement(
      id: 'wall',
      type: ElementType.wall,
      position: const Offset(450, 340),
      size: const Size(100, 15),
    );
    final mapKey = GlobalKey<StoreMapState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StoreMap(
            key: mapKey,
            controller: InventoryController(),
            layout: [wall, cashier],
            mode: MapMode.manage,
            viewStyle: MapViewStyle.twoD,
            showMobileToolbar: false,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('cashier')));
    mapKey.currentState!.applySidebarAction(MapSidebarAction.rotate);
    expect(cashier.rotation, 0);
  });
}
