import 'package:flutter/material.dart';
import '../models/currency.dart';
import '../services/app_state.dart';
import '../services/formatters.dart';
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
  late String _currencyCode;

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
    _currencyCode = profile.currencyCode;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _goalController.dispose();
    _incomeController.dispose();
    _locationController.dispose();
    _occupationController.dispose();
    _savingsGoalController.dispose();
    super.dispose();
  }

  void _savePersonal() {
    final income = double.tryParse(_incomeController.text.trim());
    final savingsGoal = double.tryParse(_savingsGoalController.text.trim());
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
            controller: _savingsGoalController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppTextStyles.dmMono(),
            decoration: InputDecoration(
              labelText: 'Savings goal (optional)',
              prefixText: '${currencySymbolFor(_currencyCode)} ',
            ),
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
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _savePersonal, child: const Text('Save personal info')),
        ],
      ),
    );
  }
}
