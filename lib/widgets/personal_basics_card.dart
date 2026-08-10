import 'package:flutter/material.dart';
import '../models/currency.dart';
import '../models/profile.dart';
import '../services/app_state.dart';
import '../services/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import 'app_card.dart';

class PersonalBasicsCard extends StatefulWidget {
  const PersonalBasicsCard({super.key, required this.appState});

  final AppState appState;

  @override
  State<PersonalBasicsCard> createState() => _PersonalBasicsCardState();
}

class _PersonalBasicsCardState extends State<PersonalBasicsCard> {
  late final TextEditingController _nameController;
  late final TextEditingController _goalController;
  late final TextEditingController _incomeController;
  late final TextEditingController _locationController;
  late final TextEditingController _occupationController;
  late final TextEditingController _savingsGoalController;
  late final TextEditingController _goalTargetDateController;
  late final TextEditingController _fixedObligationsController;
  late final TextEditingController _dependentsController;
  late String _currencyCode;
  DateTime? _goalTargetDate;
  late String _riskTolerance;

  @override
  void initState() {
    super.initState();
    final profile = widget.appState.profile;
    _nameController = TextEditingController(text: profile.displayName);
    _goalController = TextEditingController(text: profile.financialGoal);
    _incomeController = TextEditingController(
      text: profile.typicalMonthlyIncome == null ? '' : profile.typicalMonthlyIncome!.toStringAsFixed(0),
    );
    _locationController = TextEditingController(text: profile.location);
    _occupationController = TextEditingController(text: profile.occupation);
    _savingsGoalController = TextEditingController(
      text: profile.savingsGoalAmount == null ? '' : profile.savingsGoalAmount!.toStringAsFixed(0),
    );
    _goalTargetDateController = TextEditingController(
      text: profile.goalTargetDate == null ? '' : formatMDY(profile.goalTargetDate!),
    );
    _fixedObligationsController = TextEditingController(
      text: profile.monthlyFixedObligations == null
          ? ''
          : profile.monthlyFixedObligations!.toStringAsFixed(0),
    );
    _dependentsController = TextEditingController(
      text: profile.dependents == null ? '' : profile.dependents!.toString(),
    );
    _currencyCode = profile.currencyCode;
    _goalTargetDate = profile.goalTargetDate;
    _riskTolerance = profile.riskTolerance;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _goalController.dispose();
    _incomeController.dispose();
    _locationController.dispose();
    _occupationController.dispose();
    _savingsGoalController.dispose();
    _goalTargetDateController.dispose();
    _fixedObligationsController.dispose();
    _dependentsController.dispose();
    super.dispose();
  }

  Future<void> _pickGoalTargetDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _goalTargetDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 20)),
    );
    if (picked == null) return;
    setState(() {
      _goalTargetDate = picked;
      _goalTargetDateController.text = formatMDY(picked);
    });
  }

  void _savePersonal() {
    final income = double.tryParse(_incomeController.text.trim());
    final savingsGoal = double.tryParse(_savingsGoalController.text.trim());
    final fixedObligations = double.tryParse(_fixedObligationsController.text.trim());
    final dependents = int.tryParse(_dependentsController.text.trim());
    widget.appState.updateProfile(
      widget.appState.profile.copyWith(
        displayName: _nameController.text.trim(),
        financialGoal: _goalController.text.trim(),
        typicalMonthlyIncome: income,
        clearTypicalMonthlyIncome: income == null,
        location: _locationController.text.trim(),
        occupation: _occupationController.text.trim(),
        currencyCode: _currencyCode,
        savingsGoalAmount: savingsGoal,
        clearSavingsGoalAmount: savingsGoal == null,
        goalTargetDate: _goalTargetDate,
        clearGoalTargetDate: _goalTargetDate == null,
        riskTolerance: _riskTolerance,
        monthlyFixedObligations: fixedObligations,
        clearMonthlyFixedObligations: fixedObligations == null,
        dependents: dependents,
        clearDependents: dependents == null,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Personal info saved')));
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Personal basics', style: AppTextStyles.cardHeading()),
          const SizedBox(height: 16),
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Display name')),
          const SizedBox(height: 12),
          TextField(
            controller: _locationController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Location (optional)'),
          ),
          const SizedBox(height: 12),
          Text('Currency', style: AppTextStyles.metadata()),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: _currencyCode,
            isExpanded: true,
            items: supportedCurrencies.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(() => _currencyCode = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _occupationController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Occupation (optional)'),
          ),
          const SizedBox(height: 12),
          TextField(controller: _goalController, decoration: const InputDecoration(labelText: 'Financial goal')),
          const SizedBox(height: 12),
          TextField(
            controller: _goalTargetDateController,
            readOnly: true,
            onTap: _pickGoalTargetDate,
            decoration: const InputDecoration(
              labelText: 'Goal target date (optional)',
              hintText: 'Pick a date',
              suffixIcon: Icon(Icons.calendar_today_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _savingsGoalController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppTextStyles.dmMono(),
            decoration: InputDecoration(
              labelText: 'Savings goal (optional)',
              prefixText: '${currencySymbolFor(_currencyCode)} ',
            ),
          ),
          const SizedBox(height: 12),
          Text('Risk tolerance', style: AppTextStyles.metadata()),
          const SizedBox(height: 8),
          _RiskToleranceSelector(
            selected: _riskTolerance,
            onChanged: (v) => setState(() => _riskTolerance = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _incomeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppTextStyles.dmMono(),
            decoration: InputDecoration(
              labelText: 'Typical monthly income',
              prefixText: '${currencySymbolFor(_currencyCode)} ',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _fixedObligationsController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppTextStyles.dmMono(),
            decoration: InputDecoration(
              labelText: 'Fixed monthly obligations (optional)',
              prefixText: '${currencySymbolFor(_currencyCode)} ',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _dependentsController,
            keyboardType: TextInputType.number,
            style: AppTextStyles.dmMono(),
            decoration: const InputDecoration(labelText: 'Dependents (optional)'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _savePersonal, child: const Text('Save personal info')),
        ],
      ),
    );
  }
}

/// Three-way segmented pill control for [Profile.riskTolerance], mirroring
/// `_RangeSelector` in cash_flow_chart.dart (same pattern already duplicated
/// there and in analysis_screen.dart).
class _RiskToleranceSelector extends StatelessWidget {
  const _RiskToleranceSelector({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Row(
        children: [
          for (final option in riskToleranceOptions) Expanded(child: _segment(option)),
        ],
      ),
    );
  }

  Widget _segment(String option) {
    final isSelected = option == selected;
    return GestureDetector(
      onTap: () => onChanged(option),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.darkGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        alignment: Alignment.center,
        child: Text(
          option,
          style: AppTextStyles.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? AppColors.paper : AppColors.ink60,
          ),
        ),
      ),
    );
  }
}
