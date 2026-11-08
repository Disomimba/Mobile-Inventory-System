import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_plus/services/store_access_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final service = StoreAccessService(
    supabase: SupabaseClient('https://example.supabase.co', 'test-anon-key'),
    locationId: 'test-location',
  );

  final settings = StoreAccessSettings(
    locationId: 'test-location',
    openingTime: '08:00:00',
    closingTime: '21:00:00',
    staffAccessBeforeMinutes: 30,
    staffAccessAfterMinutes: 30,
    restrictStaffLogin: true,
    allowAdminAnytime: true,
    weeklyHours: {
      DateTime.monday: const StoreDayHours(
        openingTime: '09:00:00',
        closingTime: '17:00:00',
      ),
      DateTime.tuesday: const StoreDayHours(
        openingTime: '09:00:00',
        closingTime: '17:00:00',
        closed: true,
      ),
      DateTime.wednesday: const StoreDayHours(
        openingTime: '20:00:00',
        closingTime: '02:00:00',
      ),
    },
  );

  test('weekly hours survive database serialization', () {
    final restored = StoreAccessSettings.fromMap(settings.toMap());
    expect(restored.hoursForWeekday(DateTime.monday).openingTime, '09:00:00');
    expect(restored.hoursForWeekday(DateTime.tuesday).closed, isTrue);
    expect(restored.hoursForWeekday(DateTime.thursday).openingTime, '08:00:00');
  });

  test('closed day skips to the next opening', () {
    final window = service.resolveAccessWindow(
      settings,
      now: DateTime(2026, 11, 10, 12),
    ); // Tuesday
    expect(window.opening, DateTime(2026, 11, 11, 20));
  });

  test('overnight hours remain active on the next calendar day', () {
    final window = service.resolveAccessWindow(
      settings,
      now: DateTime(2026, 11, 12, 1),
    ); // Thursday morning
    expect(window.opening, DateTime(2026, 11, 11, 20));
    expect(window.shiftEnd, DateTime(2026, 11, 12, 2));
  });
}
