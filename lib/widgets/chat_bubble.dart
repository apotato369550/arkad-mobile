import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_message.dart';
import '../models/transaction.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../services/openrouter_service.dart';
import '../services/formatters.dart';

/// See STYLE_GUIDE.md § Chat drawer — agent (sage-tint, tight top-left) vs
/// user (dark-green, tight top-right) bubbles.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.onTransactionTap,
    required this.transactions,
  });

  final ChatMessage message;
  final ValueChanged<int> onTransactionTap;
  final List<LedgerTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;

    // Strip and parse Arkad blocks to get display text and referenced transaction IDs.
    final (displayText, referencedTransactionIds, _) = stripAndParseArkadBlocks(message.content);

    // Build a map of transaction id -> transaction for quick lookup.
    final transactionMap = {for (final t in transactions) t.id: t};

    // Filter referenced transactions to only include those that still exist.
    final referencedTransactions = [
      for (final id in referencedTransactionIds)
        if (transactionMap.containsKey(id))
          transactionMap[id]!,
    ];

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Markdown body
            MarkdownBody(
              data: displayText,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: AppTextStyles.body(color: isUser ? AppColors.paper : AppColors.ink),
                h1: AppTextStyles.cardHeading(color: isUser ? AppColors.paper : AppColors.ink),
                h2: AppTextStyles.cardHeading(color: isUser ? AppColors.paper : AppColors.ink),
                strong: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isUser ? AppColors.paper : AppColors.ink,
                ),
                a: TextStyle(
                  color: AppColors.darkGreen,
                  decoration: TextDecoration.underline,
                ),
              ),
              onTapLink: (text, href, title) async {
                if (href != null) {
                  final uri = Uri.parse(href);
                  try {
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  } catch (e) {
                    // Silently handle malformed URLs
                  }
                }
              },
            ),
            // Transaction chips (if any referenced transactions exist)
            if (referencedTransactions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final transaction in referencedTransactions)
                    _TransactionChip(
                      transaction: transaction,
                      onTap: () => onTransactionTap(transaction.id),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small tappable chip for a referenced transaction.
class _TransactionChip extends StatelessWidget {
  const _TransactionChip({required this.transaction, required this.onTap});

  final LedgerTransaction transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final amountColor = isIncome ? AppColors.darkGreen : AppColors.clay;

    return Material(
      color: isIncome ? AppColors.sageTint : AppColors.clay.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  transaction.merchant,
                  style: AppTextStyles.manrope(fontSize: 12, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                formatSignedCurrency(transaction.amount, isIncome: isIncome),
                style: AppTextStyles.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: amountColor),
              ),
              const SizedBox(width: 4),
              Text(
                formatDayHeader(transaction.date),
                style: AppTextStyles.manrope(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.ink60),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
