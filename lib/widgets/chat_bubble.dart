import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// See STYLE_GUIDE.md § Chat drawer — agent (sage-tint, tight top-left) vs
/// user (dark-green, tight top-right) bubbles.
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? AppColors.darkGreen : AppColors.sageTint,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isUser ? 20 : 4),
            topRight: Radius.circular(isUser ? 4 : 20),
            bottomLeft: const Radius.circular(20),
            bottomRight: const Radius.circular(20),
          ),
        ),
        child: Text(
          message.content,
          style: AppTextStyles.body(color: isUser ? AppColors.paper : AppColors.ink),
        ),
      ),
    );
  }
}
