import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arkad_mobile/models/chat_message.dart';
import 'package:arkad_mobile/screens/app_shell.dart';
import 'package:arkad_mobile/screens/chat_screen.dart';
import 'package:arkad_mobile/screens/conversation_list_screen.dart';
import 'package:arkad_mobile/theme/app_theme.dart';
import 'package:arkad_mobile/widgets/chat_composer.dart';
import 'support/analysis_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Readable local fallback for inspection screenshots; not production font fidelity.
    final families = <String>{'Roboto', 'Ahem'};
    for (final family in ['Fraunces', 'Manrope', 'DMMono']) {
      for (final variant in [
        'regular',
        '100',
        '200',
        '300',
        '500',
        '600',
        '700',
        '800',
        '900',
      ]) {
        families.add('${family}_$variant');
      }
    }
    for (final family in families) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/NotoSans-Variable.ttf'))).load();
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  testWidgets(
    'single line composer preserves height and sends once with Enter',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var sent = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatComposer(
              controller: controller,
              enabled: true,
              onSend: (_) async {
                sent++;
              },
            ),
          ),
        ),
      );
      final field = find.byType(TextField);
      final initial = tester.getSize(field).height;
      await tester.enterText(field, List.filled(50, 'long message').join(' '));
      await tester.pump();
      expect(tester.getSize(field).height, initial);
      expect(tester.widget<TextField>(field).maxLines, 1);
      await tester.enterText(field, 'first\nsecond\rthird');
      expect(
        controller.text,
        'firstsecond third',
      ); // Flutter removes LF before custom formatters.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(sent, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(sent, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Chat is a shell destination with hamburger and sparkle focuses input',
    (tester) async {
      final state = await testState();
      addTearDown(state.dispose);
      state.transactions = [];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AppShell(appState: state),
        ),
      );
      await tester.tap(find.byTooltip('Chat with Arkad'));
      await tester.pumpAndSettle();
      expect(find.byType(ConversationListScreen), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      expect(find.byTooltip('Open navigation menu'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode!.hasFocus, true);
      field.focusNode!.unfocus();
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      expect(
        find.text('Chat'),
        findsNWidgets(2),
      ); // Header and one drawer entry.
      await tester.tap(find.text('Ask Arkad'));
      await tester.pumpAndSettle();
      expect(field.focusNode!.hasFocus, true);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final width in [320.0, 390.0, 1100.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('hub and conversation fit width=$width text=$scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final state = await testState();
        addTearDown(state.dispose);
        state.addChatMessage(
          ChatMessage(
            id: 1,
            role: ChatRole.user,
            content:
                'How can I reduce my grocery spending without sacrificing healthy meals?',
            timestamp: DateTime(2026),
          ),
        );
        state.addChatMessage(
          ChatMessage(
            id: 2,
            role: ChatRole.assistant,
            content:
                'Start with a weekly grocery budget and compare your recurring purchases.',
            timestamp: DateTime(2026),
          ),
        );
        Widget host(Widget child) => MaterialApp(
          theme: AppTheme.light,
          builder: (context, app) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: app!,
          ),
          home: Scaffold(body: child),
        );
        final boundary = GlobalKey();
        await tester.pumpWidget(
          host(
            RepaintBoundary(
              key: boundary,
              child: ConversationListScreen(appState: state),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text(state.conversations.single.messages.first.content),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.text(state.conversations.single.messages.first.content),
          findsOneWidget,
        );
        expect(
          find.text(state.conversations.single.messages.last.content),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        if (width == 390 && scale == 1) {
          await capture(tester, boundary, 'hub');
        }
        await tester.pumpWidget(
          host(
            RepaintBoundary(
              key: boundary,
              child: ChatScreen(appState: state),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (width == 390 && scale == 1) {
          await capture(tester, boundary, 'conversation');
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets(
    'reply and error footer remains scrollable with keyboard and large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 650);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final state = await testState();
      addTearDown(state.dispose);
      state.addChatMessage(
        ChatMessage(
          id: 10,
          role: ChatRole.assistant,
          content: 'A longer response about your spending.',
          timestamp: DateTime(2026),
        ),
      );
      state.chatErrors[state.activeConversationId!] =
          'A provider error occurred. Please try again later.';
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: ChatScreen(appState: state),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Reply to Arkad'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Send message'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/test-results/chat-ui')
      ..createSync(recursive: true);
    File(
      '${directory.path}/$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
