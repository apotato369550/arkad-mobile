import 'package:flutter/material.dart';
import 'package:arkad_mobile/screens/conversation_list_screen.dart';
import 'package:arkad_mobile/screens/chat_screen.dart';
import 'dart:async';
import 'dart:io';
import 'package:arkad_mobile/services/app_state.dart';
import 'package:arkad_mobile/services/attachments/store_native.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:arkad_mobile/models/chat_message.dart';
import 'package:arkad_mobile/models/conversation.dart';
import 'package:arkad_mobile/services/attachments/store.dart';
import 'package:arkad_mobile/services/chat_images.dart';
import 'package:arkad_mobile/services/openrouter_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'support/analysis_fixtures.dart';

class MemoryImages implements AttachmentStore {
  final files = <String, Uint8List>{};
  @override
  Future<Uint8List?> read(String id) async => files[id];
  @override
  Future<void> write(String id, Uint8List bytes) async {
    files[id] = bytes;
  }

  @override
  Future<void> delete(String id) async {
    files.remove(id);
  }
}

ChatMessage message({
  String content = 'Hello',
  ChatRole role = ChatRole.user,
}) =>
    ChatMessage(id: 1, role: role, content: content, timestamp: DateTime(2026));
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'old conversations default to unarchived and quote metadata round trips',
    () {
      final c = Conversation.fromJson({
        'id': 'old',
        'title': 'Old',
        'createdAt': '2026-01-01',
      });
      expect(c.isArchived, false);
      expect(c.copyWith(isArchived: true).toJson()['isArchived'], true);
      final m = ChatMessage(
        id: 2,
        role: ChatRole.user,
        content: 'Why?',
        timestamp: DateTime(2026),
        replyToId: 1,
        replyExcerpt: 'A quote',
      );
      expect(ChatMessage.fromJson(m.toJson()).replyExcerpt, 'A quote');
    },
  );
  test(
    'archiving persists and sending unarchives without deleting history',
    () async {
      final state = await testState();
      addTearDown(state.dispose);
      state.addChatMessage(message());
      final id = state.activeConversationId!;
      state.setConversationArchived(id, true);
      expect(state.conversations.single.isArchived, true);
      state.addChatMessage(message(content: 'Follow up'));
      expect(state.conversations.single.isArchived, false);
      expect(state.conversations.single.messages, hasLength(2));
    },
  );
  test('late reply cannot resurrect a deleted conversation', () async {
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final state = await testState(
      handler: (_) {
        started.complete();
        return response.future;
      },
    );
    addTearDown(state.dispose);
    state.addChatMessage(message());
    final id = state.activeConversationId!;
    final pending = state.requestChatReply(id);
    await started.future;
    expect(await state.requestChatReply(id), isNull);
    await state.deleteConversation(id);
    response.complete(completionResponse());
    expect(await pending, isNull);
    expect(state.conversations, isEmpty);
  });
  test('currency prompt uses configured PHP and quoted context', () async {
    late Map<String, dynamic> body;
    final state = await testState(
      handler: (request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return completionResponse();
      },
    );
    addTearDown(state.dispose);
    state.updateProfile(state.profile.copyWith(currencyCode: 'PHP'));
    state.addChatMessage(
      ChatMessage(
        id: 3,
        role: ChatRole.user,
        content: 'Why?',
        timestamp: DateTime(2026),
        replyToId: 2,
        replyExcerpt: 'Save more',
      ),
    );
    await state.requestChatReply(state.activeConversationId!);
    final messages = body['messages'] as List;
    expect(messages.first['content'], contains('₱'));
    expect(messages.first['content'], contains('PHP'));
    expect(messages.last['content'], contains('Quoted assistant response'));
  });
  test(
    'image normalization rejects invalid data and caps processed dimensions',
    () async {
      await expectLater(
        prepareChatImage(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
      final bytes = await prepareChatImage(
        image.encodePng(image.Image(width: 1700, height: 100)),
      );
      expect(bytes.length, lessThanOrEqualTo(maxChatImageBytes));
      expect(image.decodeJpg(bytes)!.width, 1600);
    },
  );
  test(
    'images survive snapshot v2 and malformed restore leaves history intact',
    () async {
      final persistence = await testPersistence();
      final store = MemoryImages();
      persistence.attachmentStore = store;
      final state = await testState();
      addTearDown(state.dispose);
      // Use the same fake for state and persistence through a fresh service state.
      final bytes = await prepareChatImage(
        image.encodePng(image.Image(width: 10, height: 10)),
      );
      await store.write('photo', bytes);
      final json = message().toJson()
        ..['attachments'] = [
          {'id': 'photo', 'size': bytes.length},
        ];
      await persistence.saveConversations([
        Conversation(
          id: 'c',
          title: 'Photo',
          createdAt: DateTime(2026),
          messages: [ChatMessage.fromJson(json)],
        ),
      ]);
      final backup = await persistence.buildBackupSnapshot();
      expect(backup['version'], 2);
      await persistence.restoreBackupSnapshot(backup);
      final a = persistence
          .loadConversations()
          .single
          .messages
          .single
          .attachments
          .single;
      expect(await store.read(a.id), bytes);
      final corrupt = Map<String, dynamic>.from(backup)
        ..['images'] = <String, dynamic>{};
      await expectLater(
        persistence.restoreBackupSnapshot(corrupt),
        throwsFormatException,
      );
      expect(persistence.loadConversations().single.id, 'c');
    },
  );
  test('provider failure does not duplicate user messages', () async {
    final state = await testState(
      handler: (_) async =>
          http.Response('{"error":{"message":"Invalid key"}}', 401),
    );
    addTearDown(state.dispose);
    state.addChatMessage(message());
    final id = state.activeConversationId!;
    await expectLater(
      state.requestChatReply(id),
      throwsA(isA<OpenRouterException>()),
    );
    expect(state.conversations.single.messages, hasLength(1));
    expect(state.isChatRequesting(id), false);
  });
  testWidgets(
    'hub creates no empty conversation and sends first message exactly once',
    (tester) async {
      var calls = 0;
      final state = await testState(
        handler: (_) async {
          calls++;
          return completionResponse();
        },
      );
      addTearDown(state.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ConversationListScreen(appState: state)),
        ),
      );
      expect(find.text('What can Arkad help with?'), findsOneWidget);
      expect(find.byTooltip('Attach images (up to 3)'), findsOneWidget);
      expect(state.conversations, isEmpty);
      await tester.enterText(find.byType(TextField), 'Help with my budget');
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(calls, 1);
      expect(state.conversations.single.messages, hasLength(2));
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      await tester.tap(find.byTooltip('Reply to Arkad'));
      await tester.pump();
      expect(find.text('Replying to Arkad'), findsOneWidget);
      await tester.tap(find.byTooltip('Cancel reply'));
      await tester.pump();
      expect(find.text('Replying to Arkad'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test('multimodal request includes retained images', () async {
    late Map<String, dynamic> payload;
    final state = await testState(
      handler: (r) async {
        payload = jsonDecode(r.body) as Map<String, dynamic>;
        return completionResponse();
      },
    );
    addTearDown(state.dispose);
    final store = MemoryImages();
    final bytes = await prepareChatImage(
      image.encodePng(image.Image(width: 10, height: 10)),
    );
    await store.write('photo', bytes);
    final m = ChatMessage.fromJson(
      message().toJson()
        ..['attachments'] = [
          {'id': 'photo', 'size': bytes.length},
        ],
    );
    final provider = OpenRouterService(
      client: MockClient((r) async {
        payload = jsonDecode(r.body) as Map<String, dynamic>;
        return completionResponse();
      }),
    );
    await provider.sendMessage(
      apiKey: 'test',
      modelSlug: 'test/model',
      userMessage: '',
      history: [m],
      ledger: [],
      incomeCategories: [],
      expenseCategories: [],
      profile: state.profile,
      attachmentStore: store,
    );
    expect(
      (payload['messages'] as List).last['content'][1]['image_url']['url'],
      startsWith('data:image/jpeg;base64,'),
    );
  });
  test('native files reopen and reject path traversal', () async {
    final root = await Directory.systemTemp.createTemp('arkad_chat_test');
    addTearDown(() => root.delete(recursive: true));
    final store = NativeAttachmentStore(root: root);
    final bytes = Uint8List.fromList([1, 2, 3]);
    await store.write('safe_id', bytes);
    expect(await NativeAttachmentStore(root: root).read('safe_id'), bytes);
    await expectLater(store.read('../escape'), throwsFormatException);
    await store.delete('safe_id');
    expect(await store.read('safe_id'), isNull);
  });
  test(
    'image-only submissions persist, enforce count, and delete associated bytes',
    () async {
      final persistence = await testPersistence();
      final store = MemoryImages();
      final state = AppState(persistence, attachmentStore: store);
      addTearDown(state.dispose);
      final bytes = await prepareChatImage(
        image.encodePng(image.Image(width: 10, height: 10)),
      );
      await expectLater(
        state.submitChatMessage(text: '', images: [bytes, bytes, bytes, bytes]),
        throwsFormatException,
      );
      expect(state.conversations, isEmpty);
      final id = await state.submitChatMessage(
        text: '',
        images: [bytes],
        newConversation: true,
      );
      expect(state.conversations.single.title, 'Image conversation');
      expect(
        persistence.loadConversations().single.messages.single.attachments,
        hasLength(1),
      );
      expect(store.files, hasLength(1));
      await state.deleteConversation(id);
      expect(store.files, isEmpty);
      expect(persistence.loadConversations(), isEmpty);
    },
  );
  test(
    'hung chat times out, permits retry, and ignores the late original response',
    () async {
      final original = Completer<http.Response>();
      final started = Completer<void>();
      var calls = 0;
      final state = await testState(
        chatReplyTimeout: const Duration(milliseconds: 150),
        handler: (_) {
          calls++;
          if (calls == 1) {
            started.complete();
            return original.future;
          }
          return Future.value(completionResponse('Retry succeeded'));
        },
      );
      addTearDown(state.dispose);
      state.addChatMessage(message());
      final id = state.activeConversationId!;
      final pending = state.requestChatReply(id);
      final expectation = expectLater(
        pending,
        throwsA(isA<OpenRouterException>()),
      );
      await started.future.timeout(const Duration(seconds: 3));
      await expectation;
      expect(state.isChatRequesting(id), false);
      expect(state.chatErrors[id], contains('too long'));
      await state.requestChatReply(id);
      expect(state.chatErrors[id], isNull);
      original.complete(completionResponse('Late result must be discarded'));
      await Future<void>.delayed(Duration.zero);
      expect(state.conversations.single.messages, hasLength(2));
      expect(
        state.conversations.single.messages.last.content,
        'Retry succeeded',
      );
    },
  );
  test('Stop releases a pending chat without adding a late reply', () async {
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final state = await testState(
      handler: (_) {
        started.complete();
        return response.future;
      },
    );
    addTearDown(state.dispose);
    state.addChatMessage(message());
    final id = state.activeConversationId!;
    final request = state.requestChatReply(id);
    final expectation = expectLater(
      request,
      throwsA(isA<OpenRouterException>()),
    );
    await started.future;
    state.stopChatReply(id);
    await expectation;
    expect(state.isChatRequesting(id), false);
    expect(state.chatErrors[id], contains('Stopped'));
    response.complete(completionResponse('Too late'));
    await Future<void>.delayed(Duration.zero);
    expect(state.conversations.single.messages, hasLength(1));
  });
  testWidgets('Stop replaces thinking with Retry and re-enables the composer', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    final state = await testState(handler: (_) => response.future);
    addTearDown(state.dispose);
    state.addChatMessage(message());
    await tester.pumpWidget(
      MaterialApp(home: ChatScreen(appState: state, requestInitialReply: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Arkad is thinking…'), findsOneWidget);
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    expect(find.text('Arkad is thinking…'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, true);
    response.complete(completionResponse('Late response'));
    await tester.pumpAndSettle();
    expect(state.conversations.single.messages, hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });
}
