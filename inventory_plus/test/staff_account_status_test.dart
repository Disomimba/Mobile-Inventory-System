import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disabled staff cannot sign in or keep using an existing session', () {
    final login = File('supabase/schemas/public/functions/profile_login_v1.sql')
        .readAsStringSync().toLowerCase();
    final session = File('supabase/schemas/private/functions/require_app_session_v1.sql')
        .readAsStringSync().toLowerCase();
    final update = File('supabase/schemas/public/functions/update_staff_account_v1.sql')
        .readAsStringSync().toLowerCase();
    expect(login, contains('and profile.is_active'));
    expect(session, contains('and profile.is_active'));
    expect(update, contains('update private.app_sessions'));
    expect(update, contains('v_admin_role <> \'admin\''));
  });
}
