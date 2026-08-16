import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/conversation.dart';
import '../services/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../services/formatters.dart';
import 'chat_screen.dart';

/// List of past conversations, with ability to open, delete, or create new.
/// Sorted by most recent timestamp (last message or creation time).
class ConversationListScreen extends StatelessWidget {
  const ConversationListScreen({
    super.key,
    required this.appState,
    this.onTransactionTap,
  });

  final AppState appState;
  final ValueChanged<int>? onTransactionTap;

  /// Sort conversations by recency (most recent first).
  List<Conversation> _sortedConversations() {
    final sorted = [...appState.conversations];
    sorted.sort((a, b) {
      final aTimestamp = a.messages.isNotEmpty ? a.messages.last.timestamp : a.createdAt;
      final bTimestamp = b.messages.isNotEmpty ? b.messages.last.timestamp : b.createdAt;
      return bTimestamp.compareTo(aTimestamp); // Most recent first
    });
    return sorted;
  }

  void _confirmDeleteConversation(BuildContext context, Conversation conversation) {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.modal)),
        title: Text('Delete conversation?', style: AppTextStyles.cardHeading()),
        content: Text(
          'This permanently deletes "${conversation.title}" from this device.',
          style: AppTextStyles.body(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: AppTextStyles.manrope()),
          ),
          TextButton(
            onPressed: () {
              appState.deleteConversation(conversation.id);
              Navigator.of(context).pop();
            },
            child: Text(
              'Delete',
              style: AppTextStyles.manrope(color: AppColors.clay, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversations = _sortedConversations();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Past Conversations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () {
              appState.startNewConversation();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    appState: appState,
                    onTransactionTap: onTransactionTap,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: conversations.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      categoryIconAsset('chat', isIncome: true),
                      width: 48,
                      height: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No conversations yet',
                      style: AppTextStyles.cardHeading(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start chatting with Arkad to build a conversation history.',
                      style: AppTextStyles.body(color: AppColors.ink60),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: conversations.length,
              itemBuilder: (context, i) {
                final conversation = conversations[i];
                final lastMessageTime = conversation.messages.isNotEmpty
                    ? conversation.messages.last.timestamp
                    : conversation.createdAt;
                final preview = conversation.messages.isNotEmpty
                    ? conversation.messages.last.content
                    : '(empty)';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      onTap: () {
                        appState.openConversation(conversation.id);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              appState: appState,
                              onTransactionTap: onTransactionTap,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    conversation.title,
                                    style: AppTextStyles.manrope(fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    preview,
                                    style: AppTextStyles.metadata(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    formatDayHeader(lastMessageTime),
                                    style: AppTextStyles.manrope(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.ink60),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () => _confirmDeleteConversation(context, conversation),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
