import 'package:flutter/material.dart';
import 'buttons.dart';
import '../models/transaction.dart';
import '../services/app_state.dart';
import '../services/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

/// Shared create/edit modal. See STYLE_GUIDE.md § Transaction modal.
Future<void> showTransactionFormSheet(
  BuildContext context, {
  required AppState appState,
  LedgerTransaction? existing,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => TransactionFormSheet(appState: appState, existing: existing),
  );
}

class TransactionFormSheet extends StatefulWidget {
  const TransactionFormSheet({super.key, required this.appState, this.existing});

  final AppState appState;
  final LedgerTransaction? existing;

  @override
  State<TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends State<TransactionFormSheet> {
  late final TextEditingController _merchantController;
  late final TextEditingController _amountController;
  late TransactionType _type;
  late String _category;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _merchantController = TextEditingController(text: existing?.merchant ?? '');
    _amountController = TextEditingController(
      text: existing == null ? '' : existing.amount.toStringAsFixed(2),
    );
    _type = existing?.type ?? TransactionType.expense;
    final categories = _categoriesFor(_type);
    _category = existing?.category ?? (categories.isNotEmpty ? categories.first : 'General');
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  List<String> _categoriesFor(TransactionType type) =>
      type == TransactionType.income ? widget.appState.incomeCategories : widget.appState.expenseCategories;

  void _setType(TransactionType type) {
    setState(() {
      _type = type;
      final categories = _categoriesFor(type);
      _category = categories.contains(_category) ? _category : (categories.isNotEmpty ? categories.first : 'General');
    });
  }

  void _save() {
    final merchant = _merchantController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    if (merchant.isEmpty || amount == null || amount <= 0) return;

    if (_isEditing) {
      widget.appState.updateTransaction(
        widget.existing!.copyWith(merchant: merchant, amount: amount, type: _type, category: _category),
      );
    } else {
      widget.appState.addTransaction(
        LedgerTransaction(
          id: DateTime.now().millisecondsSinceEpoch,
          merchant: merchant,
          category: _category,
          date: DateTime.now(),
          amount: amount,
          type: _type,
        ),
      );
    }
    Navigator.of(context).pop();
  }

  void _delete() {
    widget.appState.deleteTransaction(widget.existing!.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final categories = _categoriesFor(_type);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isEditing ? 'Edit transaction' : 'Add transaction',
                  style: AppTextStyles.cardHeading(),
                ),
                if (_isEditing) _TypeBadge(type: _type),
              ],
            ),
            const SizedBox(height: 20),
            if (!_isEditing) ...[
              _TypeToggle(type: _type, onChanged: _setType),
              const SizedBox(height: 18),
            ],
            TextField(
              controller: _merchantController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Merchant / source'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: AppTextStyles.dmMono(),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '${currencySymbolFor(widget.appState.profile.currencyCode)} ',
              ),
            ),
            const SizedBox(height: 18),
            Text('Category', style: AppTextStyles.metadata()),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in categories)
                  _CategoryChip(
                    label: c,
                    selected: c == _category,
                    onTap: () => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _save,
              child: Text(_isEditing ? 'Update transaction' : 'Save transaction'),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 12),
              Center(child: ClayButton(label: 'Delete transaction', icon: Icons.delete_outline, onPressed: _delete)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Non-interactive type indicator shown in place of [_TypeToggle] while
/// editing — transaction type can't change after creation (see
/// STYLE_GUIDE.md § Transaction modal).
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final TransactionType type;

  @override
  Widget build(BuildContext context) {
    final isIncome = type == TransactionType.income;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isIncome ? AppColors.sageTint : AppColors.clay.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        isIncome ? 'Income' : 'Expense',
        style: AppTextStyles.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isIncome ? AppColors.darkGreen : AppColors.clay,
        ),
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.type, required this.onChanged});
  final TransactionType type;
  final ValueChanged<TransactionType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Row(
        children: [
          Expanded(child: _segment(context, 'Expense', TransactionType.expense)),
          Expanded(child: _segment(context, 'Income', TransactionType.income)),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, String label, TransactionType value) {
    final selected = type == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.darkGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.manrope(
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.paper : AppColors.ink60,
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.darkGreen : AppColors.sageTint,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Text(
          label,
          style: AppTextStyles.manrope(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: selected ? AppColors.paper : AppColors.ink,
          ),
        ),
      ),
    );
  }
}
