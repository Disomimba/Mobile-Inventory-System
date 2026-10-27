import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_plus/data/ai_insights_service.dart';
import 'package:inventory_plus/data/inventory.dart';
import 'package:inventory_plus/logic/inventory_controller.dart';
import 'package:inventory_plus/ui/dashboard_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _DashboardController extends InventoryController {
  @override
  List<CustomerOrder> get currentOrders => const [];

  @override
  List<InventoryItem> get allItems => [
    InventoryItem(
      id: 'hammer',
      name: 'Claw Hammer',
      sku: 'HAM-01',
      price: 250,
      quantity: 2,
      maxQuantity: 20,
      category: 'Tools',
      description: '',
      imageUrl: '',
    ),
  ];

  @override
  Stream<List<CustomerOrder>> get orderSnapshots => const Stream.empty();

  @override
  Stream<List<InventoryItem>> get inventorySnapshots => const Stream.empty();

  @override
  Stream<void> get transactionHistoryInvalidations => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(isOptional: true);
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key',
    );
  });

  testWidgets('dashboard fits and scrolls on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(337, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var openedTransactions = false;
    await tester.pumpWidget(MaterialApp(
      home: DashboardPage(
        controller: _DashboardController(),
        aiService: AIInsightsService(),
        isActive: false,
        onViewTransactions: () => openedTransactions = true,
        onOpenQueue: () {},
        onViewActivity: () {},
        onOpenForecasting: () {},
      ),
    ));
    await tester.pump();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Orders completed'), findsOneWidget);
    expect(find.text('Stock alerts'), findsOneWidget);
    expect(find.text('Sales · Last 7 days'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('View transactions'));
    expect(openedTransactions, isTrue);
    await tester.scrollUntilVisible(
      find.text('Order Pipeline'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Order Pipeline'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('AI Demand Forecasting'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('AI Demand Forecasting'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Recent Activity'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Recent Activity'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
