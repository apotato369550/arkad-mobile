import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arkad_mobile/models/spending_style_profile.dart';
import 'package:arkad_mobile/screens/dashboard_screen.dart';
import 'package:arkad_mobile/screens/analysis_screen.dart';
import 'package:arkad_mobile/screens/spending_style_quiz_screen.dart';
import 'package:arkad_mobile/widgets/app_card.dart';
import 'support/analysis_fixtures.dart';

void main() {
  for (final complete in [false, true]) {
    for (final width in [320.0, 390.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('quiz card complete=$complete width=$width scale=$scale', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 2400);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final state = await testState();
          state.profile = state.profile.copyWith(
            spendingStyle: SpendingStyleProfile(
              completedAt: complete ? DateTime(2026) : null,
            ),
          );
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: complete
                    ? AnalysisScreen(appState: state)
                    : DashboardScreen(
                        appState: state,
                        onTransactionTap: (_) {},
                      ),
              ),
            ),
          );
          final title = complete
              ? 'Your spending style'
              : 'What kind of spender are you?';
          final cardElement = tester.element(
            find
                .ancestor(of: find.text(title), matching: find.byType(AppCard))
                .first,
          );
          Widget? card;
          cardElement.visitAncestorElements((element) {
            card = element.widget;
            return false;
          });
          // Isolate the card so other dashboard layouts do not affect this regression.
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: card,
                  ),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          final button = find.widgetWithText(
            OutlinedButton,
            complete ? 'View results' : 'Answer quiz',
          );
          expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
          expect(
            tester.getTopLeft(button).dy,
            greaterThan(tester.getBottomLeft(find.text(title)).dy),
          );
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(find.byType(SpendingStyleQuizScreen), findsOneWidget);
          expect(
            tester
                .widget<SpendingStyleQuizScreen>(
                  find.byType(SpendingStyleQuizScreen),
                )
                .showResultInitially,
            complete,
          );
          await tester.pumpWidget(const SizedBox());
          state.dispose();
        });
      }
    }
  }
}
