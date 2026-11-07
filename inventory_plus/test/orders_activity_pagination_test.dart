import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_plus/data/inventory.dart';
import 'package:inventory_plus/logic/inventory_controller.dart';
import 'package:inventory_plus/ui/orders_activity_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _OrdersController extends InventoryController {
  @override
  Future<List<CustomerOrder>> loadActivityOrders() async => [
    for (var index = 0; index < 23; index++)
      CustomerOrder(
        id: 'SO-${index.toString().padLeft(4, '0')}',
        items: const [],
        status: 'completed',
        createdAt: DateTime(2026, 11, 8, 12).subtract(Duration(minutes: index)),
        totalAmount: 100,
        createdByName: 'Cashier Jane',
      ),
  ];

  @override
  Future<List<Map<String, dynamic>>> loadAllTransactionHistory() async => [];
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-publishable-key',
    );
  });

  testWidgets('orders show ten rows per page and search returns to page one', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrdersActivityPage(
            controller: _OrdersController(),
            isActive: true,
            onOpenQueue: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Showing 1–10 of 23'), findsOneWidget);
    expect(find.text('SO-0000'), findsOneWidget);
    expect(find.text('SO-0009'), findsOneWidget);
    expect(find.text('SO-0010'), findsNothing);

    await tester.ensureVisible(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Showing 11–20 of 23'), findsOneWidget);
    expect(find.text('SO-0010'), findsOneWidget);
    expect(find.text('SO-0020'), findsNothing);

    await tester.enterText(find.byType(TextField), 'SO-0022');
    await tester.pumpAndSettle();
    expect(find.text('Showing 1–1 of 1'), findsOneWidget);
    expect(find.text('SO-0022'), findsNWidgets(2));
  });
}
