import 'dart:typed_data';
import '../widgets/chat_composer.dart';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../models/transaction.dart';
import '../services/app_state.dart';
import '../services/openrouter_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/proposed_transactions_sheet.dart';

/// Full-screen on mobile — see STYLE_GUIDE.md § Chat drawer
/// ("Full width on smaller screens").
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.appState,
    this.onOpenSettings,
    this.onTransactionTap,
    this.requestInitialReply = false,
  });

  final bool requestInitialReply;
  final AppState appState;
  final VoidCallback? onOpenSettings;
  final ValueChanged<int>? onTransactionTap;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _composerFocus = FocusNode();
  final _messageKeys = <int, GlobalKey>{};
  ChatMessage? _replyTo;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.requestInitialReply) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _requestReply('');
      });
    }
  }

  @override
  void dispose() {
    _composerFocus.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  String _excerpt(String text) {
    final (display, _, _) = stripAndParseArkadBlocks(text);
    return display.length > 500 ? display.substring(0, 500) : display;
  }

  Future<void> _send([List<Uint8List> images = const []]) async {
    final text = _controller.text.trim();
    if ((text.isEmpty && images.isEmpty) || _sending) return;
    await widget.appState.submitChatMessage(
      text: text,
      images: images,
      replyTo: _replyTo,
    );
    if (!mounted) return;
    setState(() => _replyTo = null);
    _controller.clear();
    await _requestReply(text);
  }

  /// Sends the current chat history to OpenRouter and appends the reply.
  /// Split out from [_send] so a failed request can be retried — via the
  /// error banner's Retry chip — without re-adding the user's message.
  Future<void> _requestReply(String userMessage) async {
    if (_sending) return;
    final appState = widget.appState;
    setState(() {
      _sending = true;
      _error = null;
    });
    _scrollToBottom();

    List<LedgerTransaction> proposedTransactions = const [];
    try {
      final id = appState.activeConversationId;
      if (id == null) return;
      final reply = await appState.requestChatReply(id);
      if (reply != null && appState.activeConversationId == id) {
        proposedTransactions = reply.transactions;
      }
    } on OpenRouterException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not complete chat request: $e');
      }
    } finally {
      // Reset the "thinking" state before opening the review modal below,
      // so the loading indicator doesn't remain visible underneath it.
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }

    if (proposedTransactions.isNotEmpty && mounted) {
      await showProposedTransactionsSheet(
        context,
        appState: appState,
        drafts: proposedTransactions,
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.appState,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final appState = widget.appState;
    final hasKey = appState.hasApiKey;
    final error = _error ?? appState.chatErrors[appState.activeConversationId];

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.sageTint,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: ClipOval(
                child: Image.asset(
                  'assets/extracted/arkad_face_transparent.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Arkad',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.manrope(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    hasKey ? 'Ready to help' : 'No API key configured',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.metadata(
                      color: hasKey ? AppColors.darkGreen : AppColors.clay,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                children: [
                  const Divider(height: 1),
                  if (!hasKey)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight * 0.3,
                      ),
                      child: SingleChildScrollView(
                        child: _NoKeyBanner(
                          onOpenSettings: widget.onOpenSettings,
                        ),
                      ),
                    ),
                  Expanded(
                    child: appState.activeMessages.isEmpty
                        ? _EmptyState(
                            onSuggestion: (s) {
                              _controller.text = s;
                              if (hasKey) _send();
                            },
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(20),
                            itemCount: appState.activeMessages.length,
                            itemBuilder: (context, i) => ChatBubble(
                              key: _messageKeys.putIfAbsent(
                                appState.activeMessages[i].id,
                                () => GlobalKey(),
                              ),
                              message: appState.activeMessages[i],
                              attachmentStore: appState.attachmentStore,
                              onQuoteTap: () {
                                final target =
                                    _messageKeys[appState
                                            .activeMessages[i]
                                            .replyToId]
                                        ?.currentContext;
                                if (target != null) {
                                  Scrollable.ensureVisible(target);
                                }
                              },
                              onTransactionTap:
                                  widget.onTransactionTap ?? (_) {},
                              transactions: appState.transactions,
                              onReply: () {
                                setState(
                                  () => _replyTo = appState.activeMessages[i],
                                );
                                _composerFocus.requestFocus();
                              },
                            ),
                          ),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: constraints.maxHeight * 0.55,
                    ),
                    child: SingleChildScrollView(
                      reverse: true,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.paper,
                          border: Border(
                            top: BorderSide(color: AppColors.ink10),
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_sending ||
                                (appState.activeConversationId != null &&
                                    appState.isChatRequesting(
                                      appState.activeConversationId!,
                                    )))
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Arkad is thinking…',
                                      style: TextStyle(color: AppColors.ink),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      final id = appState.activeConversationId;
                                      if (id != null) {
                                        appState.stopChatReply(id);
                                      }
                                    },
                                    child: const Text('Stop'),
                                  ),
                                ],
                              ),
                            if (error != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        error,
                                        style: AppTextStyles.metadata(
                                          color: AppColors.clay,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed: () => _requestReply(''),
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              ),
                            if (_replyTo != null)
                              ListTile(
                                title: const Text('Replying to Arkad'),
                                subtitle: Text(
                                  _excerpt(_replyTo!.content),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: IconButton(
                                  tooltip: 'Cancel reply',
                                  icon: const Icon(Icons.close),
                                  onPressed: () =>
                                      setState(() => _replyTo = null),
                                ),
                              ),
                            ChatComposer(
                              focusNode: _composerFocus,
                              controller: _controller,
                              enabled:
                                  hasKey &&
                                  !_sending &&
                                  !(appState.activeConversationId != null &&
                                      appState.isChatRequesting(
                                        appState.activeConversationId!,
                                      )),
                              onSend: (images) => _send(images),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoKeyBanner extends StatelessWidget {
  const _NoKeyBanner({this.onOpenSettings});
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.sageTint,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "I can parse that into your ledger once you add an OpenRouter API key in Settings.",
            style: AppTextStyles.body(),
          ),
          const SizedBox(height: 4),
          Text(
            'Your key stays on this device and is never sent to Arkad.',
            style: AppTextStyles.metadata(),
          ),
          if (onOpenSettings != null) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: onOpenSettings,
              child: const Text('Open Settings'),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onSuggestion});
  final ValueChanged<String> onSuggestion;

  static const _suggestions = [
    'I bought lunch today',
    'How much did I spend on dining this month?',
    'Help me review my income',
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.sageTint,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: ClipOval(
                child: Image.asset(
                  'assets/extracted/arkad_face_transparent.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Talk to Arkad', style: AppTextStyles.cardHeading()),
            const SizedBox(height: 8),
            Text(
              'Describe a transaction or ask about your spending.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(color: AppColors.ink60),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final s in _suggestions)
                  GestureDetector(
                    onTap: () => onSuggestion(s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.sageTint,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Text(
                        s,
                        style: AppTextStyles.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
