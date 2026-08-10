import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:arkad_mobile/main.dart';

void main() {
  testWidgets('App boots into onboarding on first launch', (WidgetTester tester) async {
    // main() normally loads .env; tests skip that entrypoint, so AppConfig's
    // dotenv.maybeGet() calls would throw NotInitializedError without this.
    dotenv.testLoad(fileInput: '');
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ArkadApp());
    await tester.pumpAndSettle();

    expect(find.text('What should we call you?'), findsOneWidget);
  });
}
