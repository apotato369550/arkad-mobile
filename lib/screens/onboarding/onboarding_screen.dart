import 'package:flutter/material.dart';
import '../../models/currency.dart';
import '../../services/app_state.dart';
import '../../services/formatters.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_text_styles.dart';

/// Six-step, local-only onboarding. See STYLE_GUIDE.md § Onboarding.
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
  late final TextEditingController _savingsGoalController;
  late final TextEditingController _incomeController;
  late String _currencyCode;

  static const _titles = [
    'What should we call you?',
    'Where are you, and what\'s your currency?',
    'What do you do?',
    'What\'s your main financial goal?',
    'Do you have a savings target?',
    'What\'s your typical monthly income?',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.appState.profile.displayName);
    _locationController = TextEditingController(text: widget.appState.profile.location);
    _occupationController = TextEditingController(text: widget.appState.profile.occupation);
    _goalController = TextEditingController(text: widget.appState.profile.financialGoal);
    _savingsGoalController = TextEditingController();
    _incomeController = TextEditingController();
    _currencyCode = widget.appState.profile.currencyCode;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _occupationController.dispose();
    _goalController.dispose();
    _savingsGoalController.dispose();
    _incomeController.dispose();
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
          _savingsGoalController.clear();
        case 5:
          _incomeController.clear();
      }
    }
    if (_isLast) {
      _finish();
    } else {
      setState(() => _step += 1);
    }
  }

  void _finish() {
    final income = double.tryParse(_incomeController.text.trim());
    final savingsGoal = double.tryParse(_savingsGoalController.text.trim());
    widget.appState.updateProfile(
      widget.appState.profile.copyWith(
        displayName: _nameController.text.trim(),
        location: _locationController.text.trim(),
        currencyCode: _currencyCode,
        occupation: _occupationController.text.trim(),
        financialGoal: _goalController.text.trim(),
        savingsGoalAmount: savingsGoal,
        typicalMonthlyIncome: income,
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
              Row(
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
          controller: _savingsGoalController,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: AppTextStyles.dmMono(),
          decoration: InputDecoration(
            hintText: 'Optional',
            prefixText: '${currencySymbolFor(_currencyCode)} ',
          ),
        );
      case 5:
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
      default:
        return const SizedBox.shrink();
    }
  }
}
