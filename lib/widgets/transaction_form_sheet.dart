import 'package:flutter/material.dart';
import 'buttons.dart';
import 'category_grid.dart';
import '../models/category.dart';
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
              TypeToggle(type: _type, onChanged: _setType),
              const SizedBox(height: 18),
            ],
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.82,
                      ),
                      itemCount: categories.length,
                      itemBuilder: (context, i) {
                        final c = categories[i];
                        final iconKey = categoryIconKeyFor(c, customIcons: widget.appState.categoryIcons);
                        return CategoryGridTile(
                          label: c,
                          iconKey: iconKey,
                          isIncome: _type == TransactionType.income,
                          selected: c == _category,
                          onTap: () => setState(() => _category = c),
                        );
                      },
                    ),
                  ],
                ),
              ),
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

/// Non-interactive type indicator shown in place of [TypeToggle] while
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

