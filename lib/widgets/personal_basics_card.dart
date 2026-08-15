import 'package:flutter/material.dart';
import '../models/countries.dart';
import '../models/occupation_fields.dart';
import '../services/app_state.dart';
import '../services/formatters.dart';
import '../theme/app_text_styles.dart';
import '../widgets/country_picker_field.dart';
import '../widgets/goal_idea_chips.dart';
import '../widgets/goal_type_selector.dart';
import 'app_card.dart';

class PersonalBasicsCard extends StatefulWidget {
  const PersonalBasicsCard({super.key, required this.appState});

  final AppState appState;

  @override
  State<PersonalBasicsCard> createState() => _PersonalBasicsCardState();
}

class _PersonalBasicsCardState extends State<PersonalBasicsCard> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _jobTitleController;
  late final TextEditingController _goalOtherController;
  late final TextEditingController _longTermGoalController;
  late final TextEditingController _incomeController;
  late final TextEditingController _savingsGoalController;
  late String _countryCode;
  late String _currencyCode;
  late String _occupationField;
  late String _goalType;

  @override
  void initState() {
    super.initState();
    final profile = widget.appState.profile;
    _nameController = TextEditingController(text: profile.displayName);
    _emailController = TextEditingController(text: profile.email);
    _jobTitleController = TextEditingController(text: profile.jobTitle);
    _goalOtherController = TextEditingController(text: profile.goalOther);
    _longTermGoalController = TextEditingController(text: profile.longTermGoal);
    _incomeController = TextEditingController(
      text: profile.typicalMonthlyIncome == null ? '' : profile.typicalMonthlyIncome!.toStringAsFixed(0),
    );
    _savingsGoalController = TextEditingController(
      text: profile.savingsGoalAmount == null ? '' : profile.savingsGoalAmount!.toStringAsFixed(0),
    );
    _countryCode = profile.countryCode;
    _currencyCode = profile.currencyCode;
    _occupationField = profile.occupationField;
    _goalType = profile.goalType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _jobTitleController.dispose();
    _goalOtherController.dispose();
    _longTermGoalController.dispose();
    _incomeController.dispose();
    _savingsGoalController.dispose();
    super.dispose();
  }

  void _onCountryChanged(String code) {
    setState(() {
      _countryCode = code;
      _currencyCode = currencyCodeForCountry(code) ?? _currencyCode;
    });
  }

  void _savePersonal() {
    final income = double.tryParse(_incomeController.text.trim());
    final savingsGoal = double.tryParse(_savingsGoalController.text.trim());
    widget.appState.updateProfile(
      widget.appState.profile.copyWith(
        displayName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        countryCode: _countryCode,
        currencyCode: _currencyCode,
        jobTitle: _jobTitleController.text.trim(),
        occupationField: _occupationField,
        goalType: _goalType,
        goalOther: _goalOtherController.text.trim(),
        longTermGoal: _longTermGoalController.text.trim(),
        typicalMonthlyIncome: income,
        clearTypicalMonthlyIncome: income == null,
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
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          Text('Country', style: AppTextStyles.metadata()),
          const SizedBox(height: 8),
          CountryPickerField(countryCode: _countryCode, onChanged: _onCountryChanged),
          if (_countryCode.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Currency: $_currencyCode (${currencySymbolFor(_currencyCode)})', style: AppTextStyles.metadata()),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _jobTitleController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Job title (optional)'),
          ),
          const SizedBox(height: 12),
          Text('Field', style: AppTextStyles.metadata()),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: _occupationField.isEmpty ? null : _occupationField,
            isExpanded: true,
            hint: const Text('Select field (optional)'),
            items: occupationFields.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
            onChanged: (v) => setState(() => _occupationField = v!),
          ),
          const SizedBox(height: 16),
          Text('What do you plan to achieve with Arkad?', style: AppTextStyles.metadata()),
          const SizedBox(height: 8),
          GoalTypeSelector(
            selected: _goalType,
            onChanged: (v) => setState(() => _goalType = v),
            otherController: _goalOtherController,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _longTermGoalController,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Long-term financial goal (optional)'),
          ),
          const SizedBox(height: 8),
          const GoalIdeaList(),
          const SizedBox(height: 16),
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
