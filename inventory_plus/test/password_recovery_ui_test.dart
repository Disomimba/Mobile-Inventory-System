import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_plus/login/auth_service.dart';
import 'package:inventory_plus/ui/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _RecoveryAuthService extends AuthService {
  int requests = 0;
  int verifications = 0;

  @override
  Future<String> requestPasswordRecovery(
    String username,
    String channel,
  ) async {
    requests++;
    return 'challenge-$requests';
  }

  @override
  Future<String?> verifyPasswordRecovery(
    String challengeId,
    String code,
  ) async {
    verifications++;
    return null;
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

  testWidgets('password recovery offers email and SMS on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: ForgotPasswordModal())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Send code by'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('SMS'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Email'))
          .selected,
      isTrue,
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'SMS'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'SMS'))
          .selected,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('SMS code counts down and can be resent after one minute', (
    tester,
  ) async {
    var now = DateTime(2026, 11, 8, 12);
    final auth = _RecoveryAuthService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ForgotPasswordModal(authService: auth, now: () => now),
          ),
        ),
      ),
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'SMS'));
    await tester.enterText(find.byKey(const Key('Username')), 'admin');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(auth.requests, 1);
    expect(find.text('Code expires in 10:00'), findsOneWidget);
    expect(find.text('Resend OTP in 01:00'), findsOneWidget);

    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('Resend OTP'), findsOneWidget);
    await tester.tap(find.text('Resend OTP'));
    await tester.pumpAndSettle();
    expect(auth.requests, 2);
    expect(find.text('Code expires in 10:00'), findsOneWidget);

    now = now.add(const Duration(minutes: 10));
    await tester.pump(const Duration(minutes: 10));
    expect(find.text('Code expired'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('OTP code')), '123456');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(auth.verifications, 0);
  });
}
