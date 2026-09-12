// Basic smoke test for Khata Bondhu app.
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/main.dart';
import 'package:flutter_app/services/supabase_auth_service.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      KhataBondhuApp(
        authService: SupabaseAuthService(
          null,
          configurationError: 'Supabase is not configured for this test.',
        ),
      ),
    );
    await tester.pump();
  });
}
