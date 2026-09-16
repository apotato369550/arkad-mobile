import 'package:flutter/material.dart';
import '../models/spending_style_profile.dart';
import '../services/app_state.dart';
import '../services/openrouter_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_card.dart';

class SpendingStyleQuizScreen extends StatefulWidget {
  const SpendingStyleQuizScreen({
    super.key,
    required this.appState,
    this.showResultInitially = false,
  });
  final AppState appState;
  final bool showResultInitially;

  @override
  State<SpendingStyleQuizScreen> createState() =>
      _SpendingStyleQuizScreenState();
}

class _SpendingStyleQuizScreenState extends State<SpendingStyleQuizScreen> {
  late SpendingStyleProfile _style;
  late final TextEditingController _note;
  var _page = 0;
  var _showResult = false;
  var _generating = false;
  String? _reflectionError;

  static const _questions =
      <({String key, String title, String help, List<String> options})>[
        (
          key: 'ageRange',
          title: 'What age range feels right for you?',
          help:
              'Optional. This helps Arkad keep advice relevant without storing an exact age.',
          options: [
            '18–24',
            '25–34',
            '35–44',
            '45–54',
            '55+',
            'Prefer not to say',
          ],
        ),
        (
          key: 'incomeRhythm',
          title: 'How predictable is your income?',
          help: 'Choose the rhythm that best describes your current situation. Getting paid on a regular schedule counts as predictable income. Project-based income is not as predictable.',
          options: [
            'Mostly predictable',
            'Somewhat variable',
            'Highly variable',
            'Not earning currently',
            'Prefer not to say',
          ],
        ),
        (
          key: 'planningStyle',
          title: 'How do you usually plan spending?',
          help: 'There is no right answer here.',
          options: [
            'I make a detailed plan and budget and stick to it',
            'I use rough categories to map out my income and spend accordingly',
            'I check my balance as needed and trust my gut to guide spending',
            'I decide in the moment when I need to spend',
          ],
        ),
        (
          key: 'purchasePause',
          title: 'Before an unplanned purchase, what happens most often?',
          help: 'Pick the closest match.',
          options: [
            'I wait and compare alternative first and defer the purchase as much as possible',
            'I check my balance first to see if I can afford it',
            'I use a personal threshold/trust my gut to decide if it is worth it',
            'I usually decide immediately without thinking too much',
          ],
        ),
        (
          key: 'spendingPressure',
          title: 'What most often puts pressure on your spending?',
          help: 'This is context for guidance, not a judgment.',
          options: [
            'Convenience or lack of time',
            'Social plans and spending time with people or family',
            'Mood or rewarding myself after hard work',
            'Unexpected needs',
            'I am not sure',
          ],
        ),
        (
          key: 'flexibleCategories',
          title: 'Which costs feel most adjustable when money is tight?',
          help: 'Choose up to two, or choose none/unsure.',
          options: [
            'Groceries',
            'Eating out',
            'Shopping or personal items',
            'Entertainment',
            'Hobbies',
            'Events',
            'Travel',
            'Gym',
            'Self-care',
            'Tech gear',
            'Subscriptions',
            'Transport',
            'Car costs',
            'Gas or tolls',
            'Home items',
            'General purchases',
            'None or unsure',
          ],
        ),
        (
          key: 'savingApproach',
          title: 'How do you approach saving right now?',
          help: 'Choose what is true today.',
          options: [
            'I save automatically first',
            'I save after bills',
            'I save what remains',
            'I am not saving right now',
          ],
        ),
        (
          key: 'moneyMindset',
          title: 'How does money feel lately?',
          help: 'This helps Arkad choose a useful tone.',
          options: [
            'I feel confident',
            'I am motivated and want structure',
            'I often worry or avoid it',
            'It varies widely',
          ],
        ),
        (
          key: 'guidancePreference',
          title: 'What kind of guidance helps most?',
          help: 'You can change this later in Profile.',
          options: [
            'Concise next steps',
            'Explain the numbers',
            'Encouraging accountability',
            'Direct and candid',
          ],
        ),
        (
          key: 'contextNote',
          title: 'Anything Arkad should keep in mind?',
          help:
              'Optional. Share a boundary, priority, or situation you want reflected in guidance.',
          options: [],
        ),
      ];

  @override
  void initState() {
    super.initState();
    _style = widget.appState.profile.spendingStyle;
    _note = TextEditingController(text: _style.contextNote);
    _showResult = widget.showResultInitially && _style.isComplete;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String _valueFor(String key) => switch (key) {
    'ageRange' => _style.ageRange,
    'incomeRhythm' => _style.incomeRhythm,
    'planningStyle' => _style.planningStyle,
    'purchasePause' => _style.purchasePause,
    'spendingPressure' => _style.spendingPressure,
    'savingApproach' => _style.savingApproach,
    'moneyMindset' => _style.moneyMindset,
    'guidancePreference' => _style.guidancePreference,
    _ => '',
  };

  void _setValue(String key, String value) {
    setState(() {
      _style = switch (key) {
        'ageRange' => _style.copyWith(ageRange: value),
        'incomeRhythm' => _style.copyWith(incomeRhythm: value),
        'planningStyle' => _style.copyWith(planningStyle: value),
        'purchasePause' => _style.copyWith(purchasePause: value),
        'spendingPressure' => _style.copyWith(spendingPressure: value),
        'savingApproach' => _style.copyWith(savingApproach: value),
        'moneyMindset' => _style.copyWith(moneyMindset: value),
        'guidancePreference' => _style.copyWith(guidancePreference: value),
        _ => _style,
      };
    });
  }

  Future<void> _finish() async {
    final saved = _style.copyWith(contextNote: _note.text.trim());
    widget.appState.updateSpendingStyle(saved);
    setState(() => _showResult = true);
    if (widget.appState.hasApiKey &&
        !widget.appState.profile.spendingStyle.hasReflection) {
      await _generateReflection();
    }
  }

  Future<void> _generateReflection() async {
    if (_generating || !widget.appState.hasApiKey) return;
    setState(() {
      _generating = true;
      _reflectionError = null;
    });
    try {
      await widget.appState.generateSpendingStyleReflection();
    } on OpenRouterException catch (error) {
      _reflectionError = error.message;
    } finally {
      if (mounted) {
        setState(() => _generating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.appState.profile.spendingStyle;
    if (_showResult) {
      return _ResultScreen(
        style: style,
        hasApiKey: widget.appState.hasApiKey,
        generating: _generating,
        error: _reflectionError,
        onRegenerate: _generateReflection,
      );
    }
    final question = _questions[_page];
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('Your spending style')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: [
              LinearProgressIndicator(
                value: (_page + 1) / _questions.length,
                color: AppColors.darkGreen,
                backgroundColor: AppColors.sageTint,
              ),
              const SizedBox(height: 10),
              Text(
                '${_page + 1} of ${_questions.length}',
                style: AppTextStyles.metadata(),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: _QuestionCard(
                    question: question,
                    value: _valueFor(question.key),
                    selected: _style.flexibleCategories,
                    note: _note,
                    onChanged: (value) => _setValue(question.key, value),
                    onCategoriesChanged: (values) => setState(
                      () =>
                          _style = _style.copyWith(flexibleCategories: values),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (_page > 0)
                    OutlinedButton(
                      onPressed: () => setState(() => _page--),
                      child: const Text('Back'),
                    )
                  else
                    const SizedBox.shrink(),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _page == _questions.length - 1
                        ? _finish
                        : () => setState(() => _page++),
                    child: Text(
                      _page == _questions.length - 1 ? 'Finish quiz' : 'Next',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.value,
    required this.selected,
    required this.note,
    required this.onChanged,
    required this.onCategoriesChanged,
  });
  final ({String key, String title, String help, List<String> options})
  question;
  final String value;
  final List<String> selected;
  final TextEditingController note;
  final ValueChanged<String> onChanged;
  final ValueChanged<List<String>> onCategoriesChanged;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question.title, style: AppTextStyles.cardHeading()),
        const SizedBox(height: 10),
        Text(question.help, style: AppTextStyles.body(color: AppColors.ink60)),
        const SizedBox(height: 20),
        if (question.key == 'contextNote')
          TextField(
            controller: note,
            maxLength: 240,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'For example: I am supporting family right now.',
            ),
          )
        else if (question.key == 'flexibleCategories')
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: question.options.map((option) {
              final selectedHere = selected.contains(option);
              return FilterChip(
                label: Text(option),
                selected: selectedHere,
                onSelected: (on) {
                  var next = [...selected];
                  if (option == 'None or unsure') {
                    next = on ? [option] : [];
                  } else {
                    next.remove('None or unsure');
                    if (on && next.length < 2) next.add(option);
                    if (!on) next.remove(option);
                  }
                  onCategoriesChanged(next);
                },
              );
            }).toList(),
          )
        else
          ...question.options.map(
            (option) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    backgroundColor: value == option
                        ? AppColors.sageTint
                        : null,
                  ),
                  onPressed: () => onChanged(option),
                  child: Text(option),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _ResultScreen extends StatelessWidget {
  const _ResultScreen({
    required this.style,
    required this.hasApiKey,
    required this.generating,
    required this.error,
    required this.onRegenerate,
  });
  final SpendingStyleProfile style;
  final bool hasApiKey, generating;
  final String? error;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.cream,
    appBar: AppBar(title: const Text('Your spending style')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text(
          'A profile for better guidance',
          style: AppTextStyles.pageHeading(),
        ),
        const SizedBox(height: 10),
        Text(
          'This reflects what you told Arkad. It is not a judgment or a prediction about your spending.',
          style: AppTextStyles.body(color: AppColors.ink60),
        ),
        const SizedBox(height: 20),
        _SummaryCard(style: style),
        const SizedBox(height: 14),
        AppCard(
          color: AppColors.sageTint,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How Arkad will tailor guidance',
                style: AppTextStyles.cardHeading(),
              ),
              const SizedBox(height: 10),
              Text(_guidanceText(style), style: AppTextStyles.body()),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (generating)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            ),
          )
        else if (style.hasReflection)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  style.reflectionCurrent
                      ? 'Personal reflection'
                      : 'Personal reflection (outdated)',
                  style: AppTextStyles.cardHeading(),
                ),
                const SizedBox(height: 10),
                Text(style.reflection, style: AppTextStyles.body()),
                if (!style.reflectionCurrent && hasApiKey)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: OutlinedButton.icon(
                      onPressed: onRegenerate,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Regenerate reflection'),
                    ),
                  ),
              ],
            ),
          )
        else if (hasApiKey)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Personal reflection', style: AppTextStyles.cardHeading()),
                const SizedBox(height: 8),
                Text(
                  'Arkad can add a short reflection based on your answers and goals.',
                  style: AppTextStyles.body(color: AppColors.ink60),
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: onRegenerate,
                  child: const Text('Generate reflection'),
                ),
              ],
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              error!,
              style: AppTextStyles.body(color: AppColors.clay),
            ),
          ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ),
      ],
    ),
  );
}

class SpendingStyleSummary extends StatelessWidget {
  const SpendingStyleSummary({super.key, required this.style});
  final SpendingStyleProfile style;
  @override
  Widget build(BuildContext context) => _SummaryCard(style: style);
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.style});
  final SpendingStyleProfile style;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What you told Arkad', style: AppTextStyles.cardHeading()),
        const SizedBox(height: 12),
        ..._facts(style).map(
          (fact) => Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Text('• $fact', style: AppTextStyles.body()),
          ),
        ),
        if (_facts(style).isEmpty)
          Text(
            'You completed the quiz without selecting preferences. You can add them anytime from Profile.',
            style: AppTextStyles.body(color: AppColors.ink60),
          ),
      ],
    ),
  );
}

List<String> _facts(SpendingStyleProfile style) => [
  if (style.incomeRhythm.isNotEmpty)
    'Your income feels ${style.incomeRhythm.toLowerCase()}.',
  if (style.planningStyle.isNotEmpty) 'You said: ${style.planningStyle}.',
  if (style.savingApproach.isNotEmpty)
    'Your current saving approach: ${style.savingApproach.toLowerCase()}.',
  if (style.guidancePreference.isNotEmpty)
    'You prefer ${style.guidancePreference.toLowerCase()} guidance.',
  if (style.flexibleCategories.isNotEmpty)
    'You may want to review: ${style.flexibleCategories.join(', ')}.',
];

String _guidanceText(SpendingStyleProfile style) {
  final preference = style.guidancePreference.isEmpty
      ? 'practical, non-judgmental'
      : style.guidancePreference.toLowerCase();
  final planning = style.planningStyle.isEmpty
      ? 'your chosen approach'
      : style.planningStyle.toLowerCase();
  return 'Arkad will use $preference guidance and keep suggestions compatible with $planning. Your ledger and goals remain the evidence for financial conclusions.';
}
