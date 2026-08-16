import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/app_state.dart';
import '../services/openrouter_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../widgets/chat_bubble.dart';

/// Full-screen on mobile — see STYLE_GUIDE.md § Chat drawer
/// ("Full width on smaller screens").
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.appState, this.onOpenSettings, this.onTransactionTap});

  final AppState appState;
  final VoidCallback? onOpenSettings;
  final ValueChanged<int>? onTransactionTap;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _service = OpenRouterService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
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

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    widget.appState.addChatMessage(ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch,
      role: ChatRole.user,
      content: text,
      timestamp: DateTime.now(),
    ));
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

    try {
      final reply = await _service.sendMessage(
        apiKey: appState.effectiveApiKey,
        modelSlug: appState.apiConfig.modelSlug,
        userMessage: userMessage,
        history: appState.activeMessages,
        ledger: appState.transactions,
        incomeCategories: appState.incomeCategories,
        expenseCategories: appState.expenseCategories,
        profile: appState.profile,
      );
      if (reply.transaction != null) {
        appState.addTransaction(reply.transaction!);
      }
      appState.addChatMessage(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch + 1,
        role: ChatRole.assistant,
        content: reply.text,
        timestamp: DateTime.now(),
      ));
    } on OpenRouterException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    final hasKey = appState.hasApiKey;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(color: AppColors.sageTint, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: ClipOval(
                child: Image.asset('assets/extracted/arkad_face_transparent.png', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Arkad', style: AppTextStyles.manrope(fontWeight: FontWeight.w700)),
                Text(
                  hasKey ? 'Ready to help' : 'No API key configured',
                  style: AppTextStyles.metadata(color: hasKey ? AppColors.darkGreen : AppColors.clay),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => setState(() => widget.appState.startNewConversation()),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Divider(height: 1),
            if (!hasKey) _NoKeyBanner(onOpenSettings: widget.onOpenSettings),
            Expanded(
              child: appState.activeMessages.isEmpty
                  ? _EmptyState(onSuggestion: (s) {
                      _controller.text = s;
                      if (hasKey) _send();
                    })
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(20),
                      itemCount: appState.activeMessages.length,
                      itemBuilder: (context, i) => ChatBubble(
                        message: appState.activeMessages[i],
                        onTransactionTap: widget.onTransactionTap ?? (_) {},
                        transactions: appState.transactions,
                      ),
                    ),
            ),
            if (_sending)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Arkad is thinking…', style: TextStyle(color: AppColors.ink)),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_error!, style: AppTextStyles.metadata(color: AppColors.clay)),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        // Extract last user message from history for retry
                        String lastUserMessage = '';
                        for (final msg in widget.appState.activeMessages.reversed) {
                          if (msg.role == ChatRole.user) {
                            lastUserMessage = msg.content;
                            break;
                          }
                        }
                        _requestReply(lastUserMessage);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.sageTint,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: Text(
                          'Retry',
                          style: AppTextStyles.manrope(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            _Composer(
              controller: _controller,
              enabled: hasKey && !_sending,
              onSend: _send,
            ),
          ],
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
          Text('Your key stays on this device and is never sent to Arkad.', style: AppTextStyles.metadata()),
          if (onOpenSettings != null) ...[
            const SizedBox(height: 10),
            TextButton(onPressed: onOpenSettings, child: const Text('Open Settings')),
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
    'I spent \$12 on lunch at Chipotle',
    'How much did I spend on dining this month?',
    'Got paid \$3200 today',
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
              decoration: const BoxDecoration(color: AppColors.sageTint, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: ClipOval(
                child: Image.asset('assets/extracted/arkad_face_transparent.png', fit: BoxFit.cover),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.sageTint,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Text(s, style: AppTextStyles.manrope(fontSize: 13, fontWeight: FontWeight.w600)),
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

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.enabled, required this.onSend});

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              decoration: InputDecoration(
                hintText: enabled ? 'Message Arkad…' : 'Add an API key in Settings to chat',
                fillColor: AppColors.cream,
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: enabled ? AppColors.darkGreen : AppColors.ink10,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: enabled ? onSend : null,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Icon(Icons.arrow_upward, color: enabled ? AppColors.pastelYellow : AppColors.ink40, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
