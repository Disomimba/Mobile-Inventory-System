import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_plus/data/inventory.dart';
import 'package:inventory_plus/logic/orders_activity_metrics.dart';

void main() {
  test(
    'payment totals use collected cash and GCash, excluding cancelled orders',
    () {
      CustomerOrder order(
        String id,
        String status,
        String method,
        double total,
      ) => CustomerOrder(
        id: id,
        items: const [],
        status: status,
        createdAt: DateTime(2026, 11, 8),
        paymentMode: method,
        totalAmount: total,
      );

      final totals = PaymentTotals.fromOrders([
        order('1', 'pending', 'Cash', 100),
        order('2', 'prepared', 'GCash', 250),
        order('3', 'completed', 'Cash', 50),
        order('4', 'cancelled', 'GCash', 400),
        order('5', 'returned', 'Cash', 300),
      ]);

      expect(totals.collected, 400);
      expect(totals.cash, 150);
      expect(totals.gcash, 250);
      expect(totals.transactions, 3);
    },
  );
}
