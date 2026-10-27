import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_plus/data/inventory.dart';
import 'package:inventory_plus/logic/inventory_controller.dart';
import 'package:inventory_plus/ui/map_editor_page.dart';
import 'package:inventory_plus/ui/store_map.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MapController extends InventoryController {
  @override
  Future<void> fetchMapLayout({bool force = false}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('mobile editor shows the map and selected object controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(337, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _MapController()
      ..storeLayout = [
        MapElement(
          id: 'shelf-1',
          type: ElementType.shelf,
          position: const Offset(80, 80),
          size: const Size(104, 48),
        ),
      ];

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(337, 760)),
          child: MapEditorPage(controller: controller),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Store Layout Designer'), findsOneWidget);
    expect(find.text('Manage Layout'), findsOneWidget);
    expect(find.text('View: 3D'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Manage Layout'));
    await tester.pump(const Duration(milliseconds: 300));
    final addButton = find.byKey(const ValueKey('map-add-elements'));
    expect(tester.getSize(addButton), const Size(44, 44));
    await tester.tap(addButton);
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.getSize(find.byKey(const ValueKey('map-palette-shelf'))),
      const Size(44, 44),
    );
    expect(tester.takeException(), isNull);

    final map = tester.widget<StoreMap>(find.byType(StoreMap));
    map.onManageSelectionChanged!(controller.storeLayout.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Shelf #1'), findsOneWidget);
    expect(find.text('Rotate 90°'), findsOneWidget);
    expect(find.text('ADJUST WIDTH'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('View: 3D'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('View: 2D'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Assign Items'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('ITEMS TO PLACE'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Preview'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('View: 2D'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
