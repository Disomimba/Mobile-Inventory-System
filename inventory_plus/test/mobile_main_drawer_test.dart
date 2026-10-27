import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_plus/navigation/main_section.dart';
import 'package:inventory_plus/ui/widgets/mobile_main_drawer.dart';

void main() {
  testWidgets('admin drawer selects a page and closes', (tester) async {
    tester.view.physicalSize = const Size(337, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final scaffoldKey = GlobalKey<ScaffoldState>();
    int? selectedIndex;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          key: scaffoldKey,
          appBar: AppBar(title: const Text('Inventory Plus')),
          drawer: MobileMainDrawer(
            sections: MainSection.forRole('admin'),
            selectedIndex: 0,
            role: 'admin',
            onSelectIndex: (index) => selectedIndex = index,
          ),
          body: const SizedBox(),
        ),
      ),
    );

    scaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Inventory'), findsOneWidget);
    expect(
      tester
          .widget<ListTile>(find.byKey(const Key('mobile-nav-dashboard')))
          .selected,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('mobile-nav-inventory')));
    await tester.pumpAndSettle();
    expect(
      selectedIndex,
      MainSection.forRole('admin').indexOf(MainSection.inventory),
    );
    expect(scaffoldKey.currentState!.isDrawerOpen, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('helper drawer only shows allowed pages', (tester) async {
    tester.view.physicalSize = const Size(337, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final scaffoldKey = GlobalKey<ScaffoldState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          key: scaffoldKey,
          drawer: MobileMainDrawer(
            sections: MainSection.forRole('helper'),
            selectedIndex: 0,
            role: 'helper',
            onSelectIndex: (_) {},
          ),
          body: const SizedBox(),
        ),
      ),
    );

    scaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();
    expect(find.text('Order queue'), findsOneWidget);
    expect(find.text('Inventory'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
    expect(find.text('System Settings'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
