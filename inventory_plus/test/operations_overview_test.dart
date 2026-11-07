import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_plus/data/inventory.dart';
import 'package:inventory_plus/ui/widgets/operations_overview.dart';
import 'package:inventory_plus/ui/widgets/order_details_drawer.dart';

void main() {
  testWidgets('order details use the inventory item photo', (tester) async {
    final order = CustomerOrder(
      id: 'SO-10481',
      items: [
        CustomerOrderItem(
          productId: 'nails',
          productName: 'Concrete Nails',
          quantity: 1,
        ),
      ],
      status: 'pending',
      createdAt: DateTime.now(),
    );
    final product = InventoryItem(
      id: 'nails',
      name: 'Concrete Nails',
      sku: 'SKU-002',
      price: 100,
      quantity: 10,
      maxQuantity: 100,
      category: 'Hardware',
      description: '',
      imageUrl: 'https://example.invalid/nails.png',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderDetailsDrawer(
            order: order,
            inventory: [product],
            onOpenQueue: () {},
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as NetworkImage).url, product.imageUrl);
  });

  testWidgets(
    'order detail actions assign and confirm cancellation on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final order = CustomerOrder(
        id: 'SO-10480',
        items: [
          CustomerOrderItem(
            productId: 'cement',
            productName: 'Cement',
            quantity: 1,
          ),
        ],
        status: 'pending',
        createdAt: DateTime.now(),
        totalAmount: 265,
      );
      String? assignedHelper;
      var cancelled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => OrderDetailsDrawer.show(
                  context,
                  order: order,
                  inventory: const [],
                  onOpenQueue: () {},
                  loadHelpers: () async => [
                    (id: 'helper-1', name: 'Rodel Bautista'),
                  ],
                  onAssignHelper: (_, helperId) async {
                    assignedHelper = helperId;
                  },
                  onCancelOrder: (_) async {
                    cancelled = true;
                  },
                ),
                child: const Text('Open order'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open order'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rodel Bautista').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Assign'));
      await tester.pumpAndSettle();
      expect(assignedHelper, 'helper-1');
      await tester.tap(find.text('Cancel order'));
      await tester.pumpAndSettle();
      expect(cancelled, isFalse);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel order'));
      await tester.pumpAndSettle();
      expect(cancelled, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in <double>[390, 1600]) {
    testWidgets('overview fits a ${width.toInt()}px viewport', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final orders = <CustomerOrder>[
        CustomerOrder(
          id: 'SO-10480',
          items: [
            CustomerOrderItem(
              productId: '1',
              productName: 'Elbow',
              quantity: 2,
            ),
          ],
          status: 'pending',
          createdAt: now,
          totalAmount: 1225,
          paymentMode: 'gcash',
          createdByName: 'Aileen Cruz',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OperationsOverview(
              name: 'Maricel Santos',
              orders: orders,
              items: const [],
              approvals: const [],
              approvalCount: 0,
              presence: null,
              onOrders: () {},
              onApprovals: () {},
              onInventory: () {},
              onStaff: () {},
              onPayments: () {},
            ),
          ),
        ),
      );

      expect(find.textContaining('Maricel'), findsOneWidget);
      expect(find.text('Order queue'), findsOneWidget);
      final chart = find.byKey(const ValueKey('sales-chart-plot'));
      final bounds = tester.getRect(chart);
      if (width == 1600) {
        final region = tester.widget<MouseRegion>(
          find.byKey(const ValueKey('sales-chart-hover-region')),
        );
        expect(region.cursor, MouseCursor.defer);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(
          location: Offset(bounds.left + 2, bounds.center.dy),
        );
        await mouse.moveTo(Offset(bounds.left + 3, bounds.center.dy));
        await tester.pumpAndSettle();
        final tooltip = find.byKey(const ValueKey('sales-chart-tooltip'));
        final start = tester.getRect(tooltip).left;
        await mouse.moveTo(Offset(bounds.right - 2, bounds.center.dy));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        final middle = tester.getRect(tooltip).left;
        await tester.pumpAndSettle();
        final end = tester.getRect(tooltip).left;
        expect(middle, greaterThan(start));
        expect(middle, lessThan(end));
        expect(find.textContaining('Running total: ₱1,225.00'), findsOneWidget);
        await mouse.removePointer();
      } else {
        await tester.tapAt(bounds.center);
        await tester.pump();
        expect(find.textContaining('Running total:'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('each queue card opens its order details', (tester) async {
    final updates = StreamController<List<CustomerOrder>>.broadcast();
    addTearDown(updates.close);
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now();
    CustomerOrder order(String id, String status, {String? helper}) =>
        CustomerOrder(
          id: id,
          items: [
            CustomerOrderItem(
              productId: 'elbow',
              productName: 'PVC Elbow 1/2"',
              quantity: 2,
              picked: helper != null && status == 'pending',
            ),
            CustomerOrderItem(
              productId: 'pipe',
              productName: 'PVC Pipe',
              quantity: 1,
            ),
          ],
          status: status,
          createdAt: now,
          totalAmount: 216,
          paymentMode: 'Cash',
          cashGiven: 500,
          changeAmount: 284,
          createdByName: 'Jomar Villanueva',
          assignedHelperId: helper == null ? null : 'helper-1',
          assignedHelperName: helper,
          assignedAt: helper == null ? null : now,
          preparedAt: status == 'prepared' ? now : null,
        );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OperationsOverview(
            name: 'Maricel Santos',
            orders: [
              order('SO-10480', 'pending'),
              order('SO-10478', 'pending', helper: 'Rodel Bautista'),
              order('SO-10476', 'prepared', helper: 'Rodel Bautista'),
            ],
            items: const [],
            approvals: const [],
            approvalCount: 0,
            presence: null,
            onOrders: () {},
            onApprovals: () {},
            onInventory: () {},
            onStaff: () {},
            onPayments: () {},
            orderUpdates: updates.stream,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    final progress = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('order-progress-SO-10478')),
    );
    expect(progress.value, 0.5);

    for (final (id, status, picked) in <(String, String, String)>[
      ('SO-10480', 'Waiting', '0 / 2'),
      ('SO-10478', 'Preparing', '1 / 2'),
      ('SO-10476', 'Ready', '2 / 2'),
    ]) {
      await tester.tap(find.text(id).first);
      await tester.pumpAndSettle();
      expect(find.byType(OrderDetailsDrawer), findsOneWidget);
      expect(find.text(status), findsOneWidget);
      expect(find.text(picked), findsOneWidget);
      if (id == 'SO-10478') {
        updates.add(<CustomerOrder>[
          CustomerOrder(
            id: id,
            items: [
              CustomerOrderItem(
                productId: 'elbow',
                productName: 'PVC Elbow 1/2"',
                quantity: 2,
                picked: true,
              ),
              CustomerOrderItem(
                productId: 'pipe',
                productName: 'PVC Pipe',
                quantity: 1,
                picked: true,
              ),
            ],
            status: 'pending',
            createdAt: now,
            totalAmount: 216,
            paymentMode: 'Cash',
            cashGiven: 500,
            changeAmount: 284,
            assignedHelperId: 'helper-1',
            assignedHelperName: 'Rodel Bautista',
          ),
        ]);
        await tester.pumpAndSettle();
        expect(find.text('2 / 2'), findsOneWidget);
      }
      expect(find.text('PVC Elbow 1/2"'), findsOneWidget);
      expect(find.text('Tendered'), findsOneWidget);
      await tester.tap(find.byTooltip('Close order details'));
      await tester.pumpAndSettle();
      expect(find.byType(OrderDetailsDrawer), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

  test('order snapshot reads persisted picked items', () {
    final order = CustomerOrder.fromJson(<String, dynamic>{
      'id': 'SO-10477',
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
      'items': <Map<String, dynamic>>[
        <String, dynamic>{
          'product_id': 'paint',
          'product_name': 'Paint',
          'quantity': 1,
          'picked': true,
        },
        <String, dynamic>{
          'product_id': 'roller',
          'product_name': 'Roller',
          'quantity': 1,
        },
      ],
    });
    expect(order.items.where((item) => item.picked).length, 1);
  });
}
