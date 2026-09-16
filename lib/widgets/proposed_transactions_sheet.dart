import 'package:flutter/material.dart';
import 'category_grid.dart';
import '../models/category.dart';
import '../models/chat_message.dart';
import '../models/transaction.dart';
import '../services/app_state.dart';
import '../services/formatters.dart';
import '../services/id_generator.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

/// Opens the review/approve modal for transactions Arkad proposed from a
/// chat message. Nothing is added to the ledger until the user taps
/// "Add N transactions" inside the sheet — see STYLE_GUIDE.md § Transaction
/// modal for the shared rounded-top modal shell this reuses.
///
/// On approval, shows a confirmation SnackBar (via a [ScaffoldMessenger]
/// captured from [context] — the caller's context, not the sheet's, since
/// the sheet's own BuildContext is no longer valid once it's popped) and
/// appends a permanent assistant chat message recording what was added.
Future<void> showProposedTransactionsSheet(
  BuildContext context, {
  required AppState appState,
  required List<LedgerTransaction> drafts,
}) async {
  final messenger = ScaffoldMessenger.of(context);

  final addedCount = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ProposedTransactionsSheet(appState: appState, drafts: drafts),
  );

  if (addedCount == null || addedCount <= 0) return;

  final label = 'Arkad added $addedCount transaction${addedCount == 1 ? '' : 's'}.';
  messenger.showSnackBar(SnackBar(content: Text(label)));
  appState.addChatMessage(ChatMessage(
    id: IdGenerator.next(),
    role: ChatRole.assistant,
    content: 'Arkad added $addedCount transaction${addedCount == 1 ? '' : 's'} to your ledger.',
    timestamp: DateTime.now(),
  ));
}

class ProposedTransactionsSheet extends StatefulWidget {
  const ProposedTransactionsSheet({super.key, required this.appState, required this.drafts});

  final AppState appState;
  final List<LedgerTransaction> drafts;

  @override
  State<ProposedTransactionsSheet> createState() => _ProposedTransactionsSheetState();
}

class _ProposedTransactionsSheetState extends State<ProposedTransactionsSheet> {
  late List<LedgerTransaction> _drafts;

  @override
  void initState() {
    super.initState();
    _drafts = List.of(widget.drafts);
  }

  void _removeAt(int index) {
    setState(() => _drafts.removeAt(index));
  }

  void _updateAt(int index, LedgerTransaction updated) {
    setState(() => _drafts[index] = updated);
  }

  void _approve() {
    for (final d in _drafts) {
      widget.appState.addTransaction(d);
    }
    Navigator.of(context).pop(_drafts.length);
  }

  void _dismiss() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final count = _drafts.length;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: const BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.modal)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.ink10, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),
            Row(
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
                Expanded(
                  child: Text(
                    'Arkad found $count transaction${count == 1 ? '' : 's'}',
                    style: AppTextStyles.cardHeading(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Flexible(
              child: _drafts.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Nothing left to add.',
                        style: AppTextStyles.body(color: AppColors.ink60),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          for (var i = 0; i < _drafts.length; i++) ...[
                            _ProposedTransactionRow(
                              appState: widget.appState,
                              draft: _drafts[i],
                              onChanged: (updated) => _updateAt(i, updated),
                              onDelete: () => _removeAt(i),
                            ),
                            if (i != _drafts.length - 1) const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            if (_drafts.isNotEmpty) ...[
              ElevatedButton(
                onPressed: _approve,
                child: Text('Add $count transaction${count == 1 ? '' : 's'}'),
              ),
              const SizedBox(height: 12),
            ],
            Center(
              child: TextButton(
                onPressed: _dismiss,
                child: const Text('Not now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One editable draft row: category icon + tappable chip to change category,
/// editable merchant and amount fields, and a delete button. Income/expense
/// type is fixed — not editable here (see STYLE_GUIDE.md § Transaction modal
/// for why type can't change post-parse).
class _ProposedTransactionRow extends StatefulWidget {
  const _ProposedTransactionRow({
    required this.appState,
    required this.draft,
    required this.onChanged,
    required this.onDelete,
  });

  final AppState appState;
  final LedgerTransaction draft;
  final ValueChanged<LedgerTransaction> onChanged;
  final VoidCallback onDelete;

  @override
  State<_ProposedTransactionRow> createState() => _ProposedTransactionRowState();
}

class _ProposedTransactionRowState extends State<_ProposedTransactionRow> {
  late final TextEditingController _merchantController;
  late final TextEditingController _amountController;
  bool _categoryExpanded = false;

  bool get _isIncome => widget.draft.type == TransactionType.income;

  List<String> get _categories =>
      _isIncome ? widget.appState.incomeCategories : widget.appState.expenseCategories;

  @override
  void initState() {
    super.initState();
    _merchantController = TextEditingController(text: widget.draft.merchant);
    _amountController = TextEditingController(text: widget.draft.amount.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _commitMerchant(String value) {
    widget.onChanged(widget.draft.copyWith(merchant: value));
  }

  void _commitAmount(String value) {
    final parsed = double.tryParse(value.trim());
    if (parsed == null) return;
    widget.onChanged(widget.draft.copyWith(amount: parsed));
  }

  void _setCategory(String category) {
    setState(() => _categoryExpanded = false);
    widget.onChanged(widget.draft.copyWith(category: category));
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final iconKey = categoryIconKeyFor(draft.category, customIcons: widget.appState.categoryIcons);
    final tint = _isIncome ? AppColors.sageTint : AppColors.clay.withValues(alpha: 0.14);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => setState(() => _categoryExpanded = !_categoryExpanded),
                child: Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(AppRadii.iconTile)),
                  child: Image.asset(categoryIconAsset(iconKey, isIncome: _isIncome)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _merchantController,
                      textCapitalization: TextCapitalization.words,
                      style: AppTextStyles.manrope(fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: _commitMerchant,
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => setState(() => _categoryExpanded = !_categoryExpanded),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: tint,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              draft.category,
                              style: AppTextStyles.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _isIncome ? AppColors.darkGreen : AppColors.clay,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _categoryExpanded ? Icons.expand_less : Icons.expand_more,
                              size: 14,
                              color: _isIncome ? AppColors.darkGreen : AppColors.clay,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  style: AppTextStyles.dmMono(fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    prefixText: '${currencySymbolFor(widget.appState.profile.currencyCode)} ',
                  ),
                  onChanged: _commitAmount,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: AppColors.ink40,
                onPressed: widget.onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (_categoryExpanded) ...[
            const SizedBox(height: 12),
            CategoryGrid(
              categories: _categories,
              selected: draft.category,
              isIncome: _isIncome,
              customIcons: widget.appState.categoryIcons,
              onSelected: _setCategory,
            ),
          ],
        ],
      ),
    );
  }
}
