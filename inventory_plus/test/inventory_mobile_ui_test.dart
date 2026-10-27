import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_plus/data/inventory.dart';
import 'package:inventory_plus/logic/inventory_controller.dart';
import 'package:inventory_plus/ui/inventory_redesign.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _InventoryController extends InventoryController {
  final disabled = InventoryItem(
    id: 'saw',
    name: 'Archived Saw',
    sku: 'SAW-04',
    price: 400,
    quantity: 1,
    maxQuantity: 20,
    category: 'Tools',
    description: '',
    imageUrl: '',
  );
  final items = <InventoryItem>[
    InventoryItem(
      id: 'hammer',
      name: 'Claw Hammer',
      sku: 'HAM-01',
      price: 250,
      quantity: 12,
      maxQuantity: 20,
      category: 'Tools',
      description: '',
      imageUrl: '',
    ),
    InventoryItem(
      id: 'drill',
      name: 'Cordless Drill',
      sku: 'DRL-02',
      price: 2400,
      quantity: 2,
      maxQuantity: 20,
      category: 'Power Tools',
      description: '',
      imageUrl: '',
    ),
    InventoryItem(
      id: 'nails',
      name: 'Box of Nails',
      sku: 'NAI-03',
      price: 80,
      quantity: 0,
      maxQuantity: 20,
      category: 'Fasteners',
      description: '',
      imageUrl: '',
    ),
  ];

  @override
  List<InventoryItem> get currentInventory => [...items, disabled];

  @override
  List<InventoryItem> get disabledItems => [disabled];

  @override
  bool get isAdmin => true;

  @override
  bool isDisabled(String id) => id == disabled.id;

  @override
  StockStatus stockStatusFor(InventoryItem item) {
    if (item.quantity == 0) return StockStatus.out;
    if (item.quantity < 5) return StockStatus.low;
    return StockStatus.ok;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key',
    );
  });

  testWidgets('phone inventory uses searchable cards and a filter sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(337, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: InventoryRedesign(
          controller: _InventoryController(),
          onSelectItem: (_) {},
          onUpdateItem: (_) async {},
          onExport: () {},
          onQrLabels: () {},
          onNewItem: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Claw Hammer'), findsOneWidget);
    expect(find.text('Cordless Drill'), findsOneWidget);
    expect(find.text('Box of Nails'), findsOneWidget);
    expect(find.text('Archived Saw'), findsNothing);
    expect(find.text('Add item'), findsOneWidget);
    expect(find.text('Filter'), findsOneWidget);
    expect(find.text('Low 1'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mobile-filter-status-low')));
    await tester.pump();
    await tester.tap(find.text('Show 1 item'));
    await tester.pumpAndSettle();
    expect(find.text('Cordless Drill'), findsOneWidget);
    expect(find.text('Claw Hammer'), findsNothing);
    expect(find.text('Low stock'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('mobile-filter-category-Power Tools')),
    );
    await tester.tap(
      find.byKey(const Key('mobile-filter-category-Power Tools')),
    );
    await tester.pump();
    await tester.tap(find.text('Show 1 item'));
    await tester.pumpAndSettle();
    expect(find.text('Low stock · Power Tools'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'HAM-01');
    await tester.pump();
    expect(find.text('Claw Hammer'), findsOneWidget);
    expect(find.text('Cordless Drill'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.tap(find.byTooltip('Inventory actions'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Show disabled items'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Archived Saw'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide inventory keeps the table layout', (tester) async {
    tester.view.physicalSize = const Size(900, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: InventoryRedesign(
          controller: _InventoryController(),
          onSelectItem: (_) {},
          onUpdateItem: (_) async {},
          onExport: () {},
          onQrLabels: () {},
          onNewItem: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('New item'), findsOneWidget);
    expect(find.text('SKU'), findsOneWidget);
    expect(find.text('Claw Hammer'), findsOneWidget);
    expect(find.text('Archived Saw'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
