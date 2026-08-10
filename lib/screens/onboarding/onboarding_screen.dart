import 'package:flutter/material.dart';
import '../../models/currency.dart';
import '../../models/profile.dart';
import '../../services/app_state.dart';
import '../../services/formatters.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_text_styles.dart';

/// Ten-step, local-only onboarding. See STYLE_GUIDE.md § Onboarding.
/// No landing/auth page on mobile — this is the app's first screen.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  late final TextEditingController _occupationController;
  late final TextEditingController _goalController;
  late final TextEditingController _goalTargetDateController;
  late final TextEditingController _savingsGoalController;
  late final TextEditingController _incomeController;
  late final TextEditingController _fixedObligationsController;
  late final TextEditingController _dependentsController;
  late String _currencyCode;
  DateTime? _goalTargetDate;
  late String _riskTolerance;

  static const _titles = [
    'What should we call you?',
    'Where are you, and what\'s your currency?',
    'What do you do?',
    'What\'s your main financial goal?',
    'When would you like to reach this?',
    'Do you have a savings target?',
    'How do you feel about risk?',
    'What\'s your typical monthly income?',
    'Any fixed monthly payments?',
    'Do you support anyone financially?',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.appState.profile.displayName);
    _locationController = TextEditingController(text: widget.appState.profile.location);
    _occupationController = TextEditingController(text: widget.appState.profile.occupation);
    _goalController = TextEditingController(text: widget.appState.profile.financialGoal);
    _goalTargetDateController = TextEditingController();
    _savingsGoalController = TextEditingController();
    _incomeController = TextEditingController();
    _fixedObligationsController = TextEditingController();
    _dependentsController = TextEditingController();
    _currencyCode = widget.appState.profile.currencyCode;
    _goalTargetDate = widget.appState.profile.goalTargetDate;
    _riskTolerance = widget.appState.profile.riskTolerance;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _occupationController.dispose();
    _goalController.dispose();
    _goalTargetDateController.dispose();
    _savingsGoalController.dispose();
    _incomeController.dispose();
    _fixedObligationsController.dispose();
    _dependentsController.dispose();
    super.dispose();
  }

  bool get _isLast => _step == _titles.length - 1;

  void _back() {
    if (_step == 0) return;
    setState(() => _step -= 1);
  }

  void _continue({bool skip = false}) {
    if (skip) {
      switch (_step) {
        case 0:
          _nameController.clear();
        case 1:
          _locationController.clear();
          _currencyCode = 'USD';
        case 2:
          _occupationController.clear();
        case 3:
          _goalController.clear();
        case 4:
          _goalTargetDate = null;
          _goalTargetDateController.clear();
        case 5:
          _savingsGoalController.clear();
        case 6:
          _riskTolerance = '';
        case 7:
          _incomeController.clear();
        case 8:
          _fixedObligationsController.clear();
        case 9:
          _dependentsController.clear();
      }
    }
    if (_isLast) {
      _finish();
    } else {
      setState(() => _step += 1);
    }
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

  void _finish() {
    final income = double.tryParse(_incomeController.text.trim());
    final savingsGoal = double.tryParse(_savingsGoalController.text.trim());
    final fixedObligations = double.tryParse(_fixedObligationsController.text.trim());
    final dependents = int.tryParse(_dependentsController.text.trim());
    widget.appState.updateProfile(
      widget.appState.profile.copyWith(
        displayName: _nameController.text.trim(),
        location: _locationController.text.trim(),
        currencyCode: _currencyCode,
        occupation: _occupationController.text.trim(),
        financialGoal: _goalController.text.trim(),
        goalTargetDate: _goalTargetDate,
        savingsGoalAmount: savingsGoal,
        riskTolerance: _riskTolerance,
        typicalMonthlyIncome: income,
        monthlyFixedObligations: fixedObligations,
        dependents: dependents,
        onboardingComplete: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < _titles.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: i == _step ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i <= _step ? AppColors.darkGreen : AppColors.ink10,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                _titles[_step],
                style: AppTextStyles.fraunces(fontSize: 34, fontWeight: FontWeight.w600, height: 1.05),
              ),
              const SizedBox(height: 28),
              _buildField(),
              const Spacer(flex: 2),
              Row(
                children: [
                  if (_step > 0)
                    TextButton(onPressed: _back, child: const Text('Back'))
                  else
                    const SizedBox(width: 64),
                  const Spacer(),
                  TextButton(onPressed: () => _continue(skip: true), child: const Text('Skip for now')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _continue(),
                    child: Text(_isLast ? 'Enter Arkad' : 'Continue'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField() {
    switch (_step) {
      case 0:
        return TextField(
          controller: _nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Your name'),
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _locationController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'City, country (optional)'),
            ),
            const SizedBox(height: 16),
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
          ],
        );
      case 2:
        return TextField(
          controller: _occupationController,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Your occupation (optional)'),
        );
      case 3:
        return TextField(
          controller: _goalController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Build a 6-month emergency fund'),
        );
      case 4:
        return TextField(
          controller: _goalTargetDateController,
          readOnly: true,
          onTap: _pickGoalTargetDate,
          decoration: const InputDecoration(
            hintText: 'Pick a date (optional)',
            suffixIcon: Icon(Icons.calendar_today_outlined, size: 20),
          ),
        );
      case 5:
        return TextField(
          controller: _savingsGoalController,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: AppTextStyles.dmMono(),
          decoration: InputDecoration(
            hintText: 'Optional',
            prefixText: '${currencySymbolFor(_currencyCode)} ',
          ),
        );
      case 6:
        return _RiskToleranceSelector(
          selected: _riskTolerance,
          onChanged: (v) => setState(() => _riskTolerance = v),
        );
      case 7:
        return TextField(
          controller: _incomeController,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: AppTextStyles.dmMono(),
          decoration: InputDecoration(
            hintText: 'Optional',
            prefixText: '${currencySymbolFor(_currencyCode)} ',
          ),
        );
      case 8:
        return TextField(
          controller: _fixedObligationsController,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: AppTextStyles.dmMono(),
          decoration: InputDecoration(
            hintText: 'Rent, loans, insurance… (optional)',
            prefixText: '${currencySymbolFor(_currencyCode)} ',
          ),
        );
      case 9:
        return TextField(
          controller: _dependentsController,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: AppTextStyles.dmMono(),
          decoration: const InputDecoration(hintText: 'Optional, defaults to 0'),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

/// Three-way segmented pill control for [Profile.riskTolerance], mirroring
/// the visual language of `_RangeSelector` in cash_flow_chart.dart (same
/// pill container + AnimatedContainer selected-segment treatment) rather
/// than a dropdown, since there are only three options.
class _RiskToleranceSelector extends StatelessWidget {
  const _RiskToleranceSelector({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(AppRadii.pill)),
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
