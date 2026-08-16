import 'package:flutter/material.dart';
import '../../models/countries.dart';
import '../../models/occupation_fields.dart';
import '../../services/app_state.dart';
import '../../services/formatters.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/country_picker_field.dart';
import '../../widgets/goal_idea_chips.dart';
import '../../widgets/goal_type_selector.dart';

/// Eight-step, local-only onboarding. See STYLE_GUIDE.md § Onboarding.
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
  late final TextEditingController _emailController;
  late final TextEditingController _jobTitleController;
  late final TextEditingController _goalOtherController;
  late final TextEditingController _longTermGoalController;
  late final TextEditingController _savingsGoalController;
  late final TextEditingController _incomeController;
  late String _countryCode;
  late String _currencyCode;
  late String _occupationField;
  late String _goalType;

  static const _titles = [
    'What should we call you?',
    'What\'s your email?',
    'Where are you from?',
    'What do you do?',
    'What do you plan to achieve with Arkad?',
    'Tell us more about your goal',
    'Do you have a savings target?',
    'What\'s your typical monthly income?',
  ];

  static const _requiredSteps = {0, 2, 4};

  @override
  void initState() {
    super.initState();
    final profile = widget.appState.profile;
    _nameController = TextEditingController(text: profile.displayName);
    _emailController = TextEditingController(text: profile.email);
    _jobTitleController = TextEditingController(text: profile.jobTitle);
    _goalOtherController = TextEditingController(text: profile.goalOther);
    _longTermGoalController = TextEditingController(text: profile.longTermGoal);
    _savingsGoalController = TextEditingController();
    _incomeController = TextEditingController();
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
    _savingsGoalController.dispose();
    _incomeController.dispose();
    super.dispose();
  }

  bool get _isLast => _step == _titles.length - 1;

  bool get _canContinue {
    switch (_step) {
      case 0:
        return _nameController.text.trim().isNotEmpty;
      case 2:
        return _countryCode.isNotEmpty;
      case 4:
        if (_goalType.isEmpty) return false;
        if (_goalType == 'Other') return _goalOtherController.text.trim().isNotEmpty;
        return true;
      default:
        return true;
    }
  }

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
          _emailController.clear();
        case 3:
          _jobTitleController.clear();
          _occupationField = '';
        case 5:
          _longTermGoalController.clear();
        case 6:
          _savingsGoalController.clear();
        case 7:
          _incomeController.clear();
      }
    }
    if (_isLast) {
      _finish();
    } else {
      setState(() => _step += 1);
    }
  }

  void _onCountryChanged(String code) {
    setState(() {
      _countryCode = code;
      _currencyCode = currencyCodeForCountry(code) ?? _currencyCode;
    });
  }

  void _finish() {
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
        savingsGoalAmount: savingsGoal,
        typicalMonthlyIncome: income,
        onboardingComplete: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _canContinue;
    final isRequired = _requiredSteps.contains(_step);
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
              const SizedBox(height: 64),
              if (_step == 0) ...[
                Text('MEET ARKAD', style: AppTextStyles.eyebrow(color: AppColors.darkGreen)),
                const SizedBox(height: 12),
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(color: AppColors.sageTint, shape: BoxShape.circle),
                  padding: const EdgeInsets.all(6),
                  child: ClipOval(
                    child: Image.asset('assets/extracted/arkad_face_transparent.png', fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                _titles[_step],
                style: AppTextStyles.fraunces(fontSize: 28, fontWeight: FontWeight.w600, height: 1.05),
              ),
              const SizedBox(height: 24),
              Expanded(child: _buildField()),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (_step > 0)
                    TextButton(onPressed: _back, child: const Text('Back'))
                  else
                    const SizedBox(width: 64),
                  const Spacer(),
                  if (!isRequired)
                    TextButton(onPressed: () => _continue(skip: true), child: const Text('Skip for now')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: canContinue ? () => _continue() : null,
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
          onChanged: (_) => setState(() {}),
        );
      case 1:
        return TextField(
          controller: _emailController,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'you@example.com'),
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CountryPickerField(countryCode: _countryCode, onChanged: _onCountryChanged),
            if (_countryCode.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Currency: $_currencyCode (${currencySymbolFor(_currencyCode)})',
                style: AppTextStyles.metadata(),
              ),
            ],
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _jobTitleController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Job title (optional)'),
            ),
            const SizedBox(height: 16),
            Text('Field', style: AppTextStyles.metadata()),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: _occupationField.isEmpty ? null : _occupationField,
              isExpanded: true,
              hint: const Text('Select field (optional)'),
              items: occupationFields
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (v) => setState(() => _occupationField = v!),
            ),
          ],
        );
      case 4:
        return GoalTypeSelector(
          selected: _goalType,
          onChanged: (v) => setState(() => _goalType = v),
          otherController: _goalOtherController,
        );
      case 5:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _longTermGoalController,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Describe your long-term financial goal (optional)'),
            ),
            const SizedBox(height: 16),
            Text('Need ideas?', style: AppTextStyles.metadata()),
            const SizedBox(height: 8),
            const GoalIdeaList(),
          ],
        );
      case 6:
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
      default:
        return const SizedBox.shrink();
    }
  }
}
