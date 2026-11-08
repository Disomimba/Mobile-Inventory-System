import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_plus/data/inventory.dart';
import 'package:inventory_plus/logic/inventory_controller.dart';
import 'package:inventory_plus/ui/map_editor_page.dart';
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

  testWidgets('clicking an empty floor cell places the selected fixture', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final layout = <MapElement>[];
    var edits = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StoreMap(
            controller: InventoryController(),
            layout: layout,
            mode: MapMode.manage,
            viewStyle: MapViewStyle.twoD,
            placementType: ElementType.rack,
            showMobileToolbar: false,
            onLayoutEdited: () => edits++,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tapAt(const Offset(600, 450));
    await tester.pump();

    expect(layout, hasLength(1));
    expect(layout.single.type, ElementType.rack);
    expect(edits, 1);
  });

  test('an assigned product can clear its map location', () {
    final item = InventoryItem(
      id: 'item-1',
      name: 'Item',
      sku: 'SKU-1',
      price: 10,
      quantity: 1,
      maxQuantity: 10,
      category: 'General',
      description: '',
      imageUrl: '',
      locationId: 'rack-1',
    );
    expect(item.copyWith(clearLocation: true).locationId, isNull);
  });

  testWidgets('Assign items tab shows the product placement workflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _MapAssignmentController()
      ..storeLayout = [
        MapElement(
          id: 'rack-1',
          type: ElementType.rack,
          position: const Offset(200, 200),
          label: 'Rack A',
        ),
      ];
    await tester.pumpWidget(
      MaterialApp(home: MapEditorPage(controller: controller)),
    );
    await tester.pump();
    expect(tester.widget<StoreMap>(find.byType(StoreMap)).mode, MapMode.manage);
    final assignTabCenter = tester.getCenter(find.text('Assign items'));
    final viewCenter = tester.getCenter(find.text('3D view'));
    expect(viewCenter.dx, greaterThan(1100));
    expect(assignTabCenter.dx, lessThan(viewCenter.dx));
    expect((assignTabCenter.dy - viewCenter.dy).abs(), lessThan(2));

    await tester.tap(find.byKey(const ValueKey('rack-1')));
    await tester.pump();
    expect(find.byKey(const ValueKey('map-label-rack-1')), findsOneWidget);
    expect(find.text('ADJUST WIDTH'), findsOneWidget);
    for (final coordinate in ['X', 'Y', 'W', 'H']) {
      expect(find.text(coordinate), findsNothing);
    }

    await tester.tap(find.text('Assign items'));
    await tester.pump();
    expect(find.text('Items to place'), findsOneWidget);
    expect(find.text('Search items or SKU…'), findsOneWidget);
    expect(
      tester.widget<StoreMap>(find.byType(StoreMap)).mode,
      MapMode.selection,
    );
    expect(
      find.text(
        'Add a rack or shelf in Manage layout before placing products.',
      ),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('map-assign-product-item-1')));
    await tester.pump();
    expect(
      tester.widget<StoreMap>(find.byType(StoreMap)).selectedItemId,
      'item-1',
    );
    await tester.tap(find.byKey(const ValueKey('rack-1')));
    await tester.pump();
    expect(controller.allItems.single.locationId, 'rack-1');
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
    final before = tester.widget<CustomPaint>(floor).size;
    await tester.pumpWidget(mapAtRotation(math.pi / 2));
    final after = tester.widget<CustomPaint>(floor).size;
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

class _MapAssignmentController extends InventoryController {
  List<InventoryItem> _testItems = [
    InventoryItem(
      id: 'item-1',
      name: 'Test product',
      sku: 'SKU-1',
      price: 10,
      quantity: 1,
      maxQuantity: 10,
      category: 'General',
      description: '',
      imageUrl: '',
    ),
  ];

  @override
  List<InventoryItem> get allItems => _testItems;

  @override
  Future<void> assignItemToLocation(String itemId, String? mapElementId) async {
    _testItems = [
      for (final item in _testItems)
        item.id == itemId
            ? item.copyWith(
                locationId: mapElementId,
                clearLocation: mapElementId == null,
              )
            : item,
    ];
  }
}
