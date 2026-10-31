import '../widgets/app_card.dart';
import '../models/chat_message.dart';
import 'dart:typed_data';
import '../widgets/chat_composer.dart';
import 'package:flutter/material.dart';
import '../services/app_state.dart';
import '../services/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'chat_screen.dart';

class ConversationListScreen extends StatefulWidget {
  const ConversationListScreen({
    super.key,
    required this.appState,
    this.onTransactionTap,
    this.autofocus = false,
    this.focusNode,
  });
  final AppState appState;
  final ValueChanged<int>? onTransactionTap;
  final bool autofocus;
  final FocusNode? focusNode;
  @override
  State<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  final _controller = TextEditingController();
  bool _archivedOnly = false;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send(List<Uint8List> images) async {
    final text = _controller.text.trim();
    if ((text.isEmpty && images.isEmpty) || !widget.appState.hasApiKey) return;
    await widget.appState.submitChatMessage(
      text: text,
      images: images,
      newConversation: true,
    );
    if (!mounted) return;
    _controller.clear();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          appState: widget.appState,
          requestInitialReply: true,
          onTransactionTap: _openTransaction,
        ),
      ),
    );
  }

  void _openTransaction(int id) {
    if (widget.onTransactionTap == null) return;
    Navigator.of(
      context,
    ).pop(); // Close the conversation before the hub callback.
    widget.onTransactionTap!(id);
  }

  String _preview(List<ChatMessage> messages, String fallback) {
    final first = messages.where((m) => m.role == ChatRole.user).firstOrNull;
    if (first == null) return fallback;
    return first.content.trim().isEmpty
        ? 'Image conversation'
        : first.content.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.appState,
    builder: (context, _) {
      final state = widget.appState;
      final items =
          state.conversations
              .where((c) => !_archivedOnly || c.isArchived)
              .toList()
            ..sort(
              (a, b) =>
                  (b.messages.isEmpty ? b.createdAt : b.messages.last.timestamp)
                      .compareTo(
                        a.messages.isEmpty
                            ? a.createdAt
                            : a.messages.last.timestamp,
                      ),
            );
      return ColoredBox(
        color: AppColors.cream,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  AppCard(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: AppColors.sageTint,
                            shape: BoxShape.circle,
                          ),
                          child: Image.asset(
                            'assets/extracted/arkad_face_transparent.png',
                            width: 48,
                            height: 48,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'What can Arkad help with?',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.pageHeading(),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ask about your spending or describe a transaction.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body(color: AppColors.ink60),
                        ),
                        const SizedBox(height: 20),
                        ChatComposer(
                          controller: _controller,
                          focusNode: widget.focusNode,
                          autofocus: widget.autofocus,
                          enabled: state.hasApiKey,
                          onSend: _send,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Conversations', style: AppTextStyles.cardHeading()),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selectedColor: AppColors.sageTint,
                        backgroundColor: AppColors.paper,
                        side: BorderSide(color: AppColors.ink10),
                        labelStyle: AppTextStyles.manrope(
                          color: AppColors.darkGreen,
                        ),
                        selected: !_archivedOnly,
                        onSelected: (_) =>
                            setState(() => _archivedOnly = false),
                      ),
                      ChoiceChip(
                        label: const Text('Archived'),
                        selectedColor: AppColors.sageTint,
                        backgroundColor: AppColors.paper,
                        side: BorderSide(color: AppColors.ink10),
                        labelStyle: AppTextStyles.manrope(
                          color: AppColors.darkGreen,
                        ),
                        selected: _archivedOnly,
                        onSelected: (_) => setState(() => _archivedOnly = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (items.isEmpty)
                    AppCard(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline,
                            color: AppColors.ink,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _archivedOnly
                                ? 'No archived conversations'
                                : 'No conversations yet',
                            style: AppTextStyles.cardHeading(),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _archivedOnly
                                ? 'Archived chats will appear here.'
                                : 'Send your first question above to get started.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  for (final c in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              _preview(c.messages, c.title),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${c.isArchived ? 'Archived · ' : ''}${formatDayHeader(c.messages.isEmpty ? c.createdAt : c.messages.last.timestamp)}',
                              style: AppTextStyles.metadata(),
                            ),
                            onTap: () {
                              state.openConversation(c.id);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    appState: state,
                                    onTransactionTap: _openTransaction,
                                  ),
                                ),
                              );
                            },
                            trailing: PopupMenuButton<String>(
                              tooltip: 'Conversation actions',
                              onSelected: (action) async {
                                if (action == 'archive') {
                                  state.setConversationArchived(
                                    c.id,
                                    !c.isArchived,
                                  );
                                } else {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete conversation?'),
                                      content: Text(
                                        'Permanently delete "${c.title}" and its retained images from this device?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    state.deleteConversation(c.id);
                                  }
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'archive',
                                  child: Text(
                                    c.isArchived ? 'Unarchive' : 'Archive',
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
