import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_plus/logic/inventory_controller.dart';
import 'package:inventory_plus/logic/staff_performance.dart';
import 'package:inventory_plus/ui/staff_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _StaffController extends InventoryController {
  _StaffController() {
    currentUserId = '1';
    currentUserRole = 'admin';
    activeLocationId = 'store-1';
  }

  String? editedName;
  bool? editedActive;
  String? editedRole;
  String? editedAddress;
  String? resetId;
  String? resetPassword;

  final staff = <Map<String, dynamic>>[
    {
      'id': 1,
      'name': 'Maricel Santos',
      'username': 'maricel',
      'email': 'maricel@example.com',
      'role': 'admin',
      'is_active': true,
    },
    {
      'id': 2,
      'name': 'Jomar Villanueva',
      'username': 'jomar',
      'email': 'jomar@example.com',
      'role': 'staff',
      'is_active': true,
    },
    {
      'id': 3,
      'name': 'Rodel Bautista',
      'username': 'rodel',
      'email': 'rodel@example.com',
      'role': 'helper',
      'is_active': false,
    },
  ];

  @override
  Stream<List<Map<String, dynamic>>> streamStaffConfiguration() =>
      Stream.value(staff);

  @override
  Future<StaffPerformanceSnapshot> loadStaffPerformance({
    required StaffPerformanceRole role,
    required DateTime periodStart,
    required DateTime periodEnd,
    bool forceRefresh = false,
  }) async => StaffPerformanceSnapshot.fromJson(
    const {'records': []},
    role: role,
    periodStart: periodStart,
    periodEnd: periodEnd,
  );

  @override
  Future<bool> updateStaffAccount({
    required String id,
    required String name,
    required String email,
    required String phone,
    String? address,
    required String role,
    required bool isActive,
  }) async {
    editedName = name;
    editedActive = isActive;
    editedRole = role;
    editedAddress = address;
    return true;
  }

  @override
  Future<bool> adminResetUserPassword(
    String targetUserId,
    String newPassword,
  ) async {
    resetId = targetUserId;
    resetPassword = newPassword;
    return true;
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-publishable-key',
    );
  });

  testWidgets('staff roster filters and edits an existing account', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _StaffController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StaffPage(controller: controller, isActive: true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('3 accounts · 0 online now'), findsOneWidget);
    expect(find.text('Jomar Villanueva'), findsOneWidget);
    expect(find.text('Location'), findsNothing);
    expect(find.text('Home address'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit Jomar Villanueva'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Jomar Villanueva'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('staff-editor-panel'))).width,
      closeTo(1600 / 3, 1),
    );
    expect(
      tester.widget<Dialog>(find.byType(Dialog)).backgroundColor,
      Colors.white,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Jomar Villanueva'),
      'Jomar V.',
    );
    await tester.enterText(find.byType(TextFormField).last, 'Quezon City');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(controller.editedName, 'Jomar V.');
    expect(controller.editedRole, 'staff');
    expect(controller.editedAddress, 'Quezon City');
  });

  testWidgets('Performance tab opens the report and returns to staff', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _StaffController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StaffPage(controller: controller, isActive: true)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Performance'));
    await tester.pumpAndSettle();
    expect(find.text('Staff Performance'), findsOneWidget);
    expect(find.text('Add staff'), findsOneWidget);
    final title = tester.getRect(find.text('Staff Performance'));
    final addButton = tester.getRect(find.text('Add staff'));
    expect((title.center.dy - addButton.center.dy).abs(), lessThan(30));

    await tester.tap(find.text('Staff list'));
    await tester.pumpAndSettle();
    expect(find.text('Jomar Villanueva'), findsOneWidget);
    expect(find.text('Staff Performance'), findsNothing);
  });

  testWidgets('role choices fit the compact staff drawer', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _StaffController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StaffPage(controller: controller, isActive: true)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit Jomar Villanueva'));
    await tester.pumpAndSettle();

    final admin = find.widgetWithText(OutlinedButton, 'Administrator');
    final cashier = find.widgetWithText(OutlinedButton, 'Cashier');
    final helper = find.widgetWithText(OutlinedButton, 'Order helper');
    expect(tester.getCenter(admin).dy, tester.getCenter(cashier).dy);
    expect(tester.getCenter(cashier).dy, tester.getCenter(helper).dy);

    tester.view.physicalSize = const Size(390, 900);
    await tester.pumpAndSettle();
    expect(tester.getSize(admin).width, greaterThan(250));
    expect(tester.getCenter(admin).dy, lessThan(tester.getCenter(cashier).dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'staff actions fit a narrow viewport and reset without expiry text',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _StaffController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaffPage(controller: controller, isActive: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Reset password for Jomar Villanueva'));
      await tester.pumpAndSettle();
      expect(find.textContaining('24 hours'), findsNothing);
      expect(find.text('CashierJV@123'), findsNothing);
      await tester.tap(find.text('Reset password').last);
      await tester.pumpAndSettle();
      expect(controller.resetId, '2');
      expect(controller.resetPassword, 'CashierJV@123');
      expect(find.text('Password issued'), findsOneWidget);
      expect(find.text('CashierJV@123'), findsOneWidget);
    },
  );
}
