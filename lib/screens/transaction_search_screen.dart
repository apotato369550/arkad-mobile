import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/app_state.dart';
import '../services/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../widgets/day_grouped_transactions.dart';
import '../widgets/transaction_form_sheet.dart';

class TransactionSearchScreen extends StatefulWidget {
  const TransactionSearchScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<TransactionSearchScreen> createState() => _TransactionSearchScreenState();
}

class _TransactionSearchScreenState extends State<TransactionSearchScreen> {
  late TextEditingController _queryController;
  late TextEditingController _minController;
  late TextEditingController _maxController;

  TransactionType? _typeFilter;
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _categoryFilter;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController();
    _minController = TextEditingController();
    _maxController = TextEditingController();

    _queryController.addListener(() => setState(() {}));
    _minController.addListener(() => setState(() {}));
    _maxController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _queryController.dispose();
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  List<String> get _availableCategories {
    if (_typeFilter == null) {
      return [...widget.appState.incomeCategories, ...widget.appState.expenseCategories];
    }
    return _typeFilter == TransactionType.income
        ? widget.appState.incomeCategories
        : widget.appState.expenseCategories;
  }

  void _onTypeFilterChanged(TransactionType? type) {
    setState(() {
      _typeFilter = type;
      // Reset category filter if it's no longer valid for the new type
      if (_categoryFilter != null && !_availableCategories.contains(_categoryFilter)) {
        _categoryFilter = null;
      }
    });
  }

  List<LedgerTransaction> get _filtered {
    final query = _queryController.text.trim().toLowerCase();
    final min = double.tryParse(_minController.text.trim());
    final max = double.tryParse(_maxController.text.trim());

    return widget.appState.recentTransactions.where((t) {
      if (query.isNotEmpty && !t.merchant.toLowerCase().contains(query)) return false;
      if (_typeFilter != null && t.type != _typeFilter) return false;
      if (min != null && t.amount < min) return false;
      if (max != null && t.amount > max) return false;
      if (_fromDate != null && t.date.isBefore(_fromDate!)) return false;
      if (_toDate != null && t.date.isAfter(_toDate!.add(const Duration(days: 1)))) return false;
      if (_categoryFilter != null && t.category != _categoryFilter) return false;
      return true;
    }).toList();
  }

  Future<void> _selectFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _fromDate = picked);
    }
  }

  Future<void> _selectToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _toDate = picked);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Search transactions'),
        backgroundColor: AppColors.cream,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          // Merchant search field
          TextField(
            controller: _queryController,
            decoration: const InputDecoration(
              hintText: 'Search by merchant name',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 20),

          // Type filter toggle
          _TypeToggle(
            type: _typeFilter,
            onChanged: _onTypeFilterChanged,
          ),
          const SizedBox(height: 20),

          // Min/Max amount row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppTextStyles.dmMono(),
                  decoration: InputDecoration(
                    labelText: 'Min amount',
                    prefixText: '${currencySymbolFor(widget.appState.profile.currencyCode)} ',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _maxController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppTextStyles.dmMono(),
                  decoration: InputDecoration(
                    labelText: 'Max amount',
                    prefixText: '${currencySymbolFor(widget.appState.profile.currencyCode)} ',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Date range row
          Row(
            children: [
              Expanded(
                child: _DateRangeField(
                  label: _fromDate != null ? _formatDate(_fromDate!) : 'From: Any',
                  onTap: _selectFromDate,
                  onClear: _fromDate != null ? () => setState(() => _fromDate = null) : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateRangeField(
                  label: _toDate != null ? _formatDate(_toDate!) : 'To: Any',
                  onTap: _selectToDate,
                  onClear: _toDate != null ? () => setState(() => _toDate = null) : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Category dropdown
          Text('Category', style: AppTextStyles.metadata()),
          const SizedBox(height: 8),
          DropdownButton<String?>(
            isExpanded: true,
            value: _categoryFilter,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Any category'),
              ),
              ..._availableCategories.map(
                (category) => DropdownMenuItem<String?>(
                  value: category,
                  child: Text(category),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _categoryFilter = value),
          ),
          const SizedBox(height: 16),

          // Results
          DayGroupedTransactions(
            transactions: _filtered,
            initialDayCount: 10,
            key: ValueKey(Object.hash(
              _queryController.text,
              _typeFilter,
              _minController.text,
              _maxController.text,
              _fromDate,
              _toDate,
              _categoryFilter,
            )),
            onTransactionTap: (t) => showTransactionFormSheet(
              context,
              appState: widget.appState,
              existing: t,
            ),
            emptyLabel: 'No transactions match your search.',
          ),
        ],
      ),
    );
  }
}

/// 3-way toggle for All / Income / Expense
class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.type, required this.onChanged});

  final TransactionType? type;
  final ValueChanged<TransactionType?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Row(
        children: [
          Expanded(child: _segment(context, 'All', null)),
          Expanded(child: _segment(context, 'Expense', TransactionType.expense)),
          Expanded(child: _segment(context, 'Income', TransactionType.income)),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, String label, TransactionType? value) {
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
            fontSize: 13,
            color: selected ? AppColors.paper : AppColors.ink60,
          ),
        ),
      ),
    );
  }
}

/// Tappable date range field with optional clear button
class _DateRangeField extends StatelessWidget {
  const _DateRangeField({
    required this.label,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.paper,
          border: Border.all(color: AppColors.sageTint),
          borderRadius: BorderRadius.circular(AppRadii.input),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTextStyles.body(),
              overflow: TextOverflow.ellipsis,
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, size: 18, color: AppColors.ink60),
              )
            else
              Icon(Icons.calendar_today, size: 16, color: AppColors.ink40),
          ],
        ),
      ),
    );
  }
}
