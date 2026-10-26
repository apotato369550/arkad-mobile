import 'package:flutter/material.dart';
import '../models/spending_style_profile.dart';
import '../services/app_state.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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

  static const _questions = <({String key, String title, String help, List<String> options})>[
    (
      key: 'ageRange',
      title: 'What age range feels right for you?',
      help:
          'Optional. This helps Arkad keep advice relevant without storing an exact age.',
      options: ['18–24', '25–34', '35–44', '45–54', '55+', 'Prefer not to say'],
    ),
    (
      key: 'incomeRhythm',
      title: 'How predictable is your income?',
      help:
          'Choose the rhythm that best describes your current situation. Getting paid on a regular schedule counts as predictable income. Project-based income is not as predictable.',
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
    final saved = _style.copyWith(
      contextNote: _note.text.trim(),
      completedAt: DateTime.now(),
    );
    widget.appState.updateSpendingStyle(saved);
    setState(() => _showResult = true);
    if (widget.appState.hasApiKey) {
      await Future.wait([
        for (final section in SpendingStyleSection.values)
          widget.appState.generateSpendingStyleSection(section),
      ]);
    }
  }

  void _retake() {
    setState(() {
      _style = widget.appState.profile.spendingStyle;
      _note.text = _style.contextNote;
      _page = 0;
      _showResult = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showResult) {
      return ListenableBuilder(
        listenable: widget.appState,
        builder: (context, _) =>
            _ResultScreen(appState: widget.appState, onRetake: _retake),
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
  const _ResultScreen({required this.appState, required this.onRetake});
  final AppState appState;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    final style = appState.profile.spendingStyle;
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('Your spending style')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Text('Guidance that fits you', style: AppTextStyles.pageHeading()),
          const SizedBox(height: 10),
          Text(
            'Your answers help Arkad understand your approach. Your actual ledger remains the evidence.',
            style: AppTextStyles.body(color: AppColors.ink60),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onRetake,
              icon: const Icon(Icons.replay_outlined),
              label: const Text('Retake Quiz'),
            ),
          ),
          const SizedBox(height: 24),
          _SummaryCard(style: style),
          const SizedBox(height: 18),
          for (final section in SpendingStyleSection.values) ...[
            _SynthesisCard(appState: appState, section: section),
            const SizedBox(height: 18),
          ],
          if (style.hasReflection)
            ExpansionTile(
              title: Text(
                'Previous reflection',
                style: AppTextStyles.manrope(),
              ),
              subtitle: const Text('Saved from an earlier version'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(style.reflection, style: AppTextStyles.body()),
                ),
              ],
            ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _SynthesisCard extends StatelessWidget {
  const _SynthesisCard({required this.appState, required this.section});
  final AppState appState;
  final SpendingStyleSection section;

  @override
  Widget build(BuildContext context) {
    final style = appState.profile.spendingStyle;
    final current = style.isCurrent(section);
    final text = style.textFor(section);
    final busy = appState.isGeneratingSpendingStyle(section);
    final error = appState.spendingStyleErrors[section];
    final assessment = section == SpendingStyleSection.assessment;
    return AppCard(
      color: assessment ? AppColors.paper : AppColors.sageTint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            assessment
                ? Icons.psychology_outlined
                : Icons.auto_awesome_outlined,
            color: AppColors.darkGreen,
            size: 28,
          ),
          const SizedBox(height: 12),
          Text(
            assessment
                ? "Arkad's Assessment"
                : 'How Arkad Will Tailor Guidance',
            style: AppTextStyles.cardHeading(),
          ),
          const SizedBox(height: 12),
          if (text.isNotEmpty) ...[
            if (!current) ...[
              Text(
                'Outdated · Your answers have changed',
                style: AppTextStyles.metadata(),
              ),
              const SizedBox(height: 8),
            ],
            MarkdownBody(
              data: text,
              styleSheet: MarkdownStyleSheet(
                p: AppTextStyles.body(),
                listBullet: AppTextStyles.body(),
              ),
            ),
          ] else
            Text(
              assessment
                  ? 'Arkad will synthesize your answers into a spending-style profile.'
                  : 'See how your preferences will shape future guidance.',
              style: AppTextStyles.body(color: AppColors.ink60),
            ),
          if (busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(
              'Creating your personalized guidance…',
              style: AppTextStyles.metadata(),
            ),
          ] else if (!current) ...[
            const SizedBox(height: 16),
            if (!appState.hasApiKey)
              Text(
                'Add an OpenRouter API key in Settings to generate this section.',
                style: AppTextStyles.body(color: AppColors.ink60),
              )
            else
              OutlinedButton.icon(
                onPressed: () => appState.generateSpendingStyleSection(section),
                icon: const Icon(Icons.refresh_outlined),
                label: Text(
                  error != null
                      ? 'Retry'
                      : text.isEmpty
                      ? 'Generate'
                      : 'Update',
                ),
              ),
          ],
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error, style: AppTextStyles.body(color: AppColors.clay)),
          ],
        ],
      ),
    );
  }
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

  String _answer(String key) => switch (key) {
    'ageRange' => style.ageRange,
    'incomeRhythm' => style.incomeRhythm,
    'planningStyle' => style.planningStyle,
    'purchasePause' => style.purchasePause,
    'spendingPressure' => style.spendingPressure,
    'flexibleCategories' => style.flexibleCategories.join(', '),
    'savingApproach' => style.savingApproach,
    'moneyMindset' => style.moneyMindset,
    'guidancePreference' => style.guidancePreference,
    'contextNote' => style.contextNote,
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    final questions = _SpendingStyleQuizScreenState._questions;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Answers', style: AppTextStyles.cardHeading()),
          const SizedBox(height: 20),
          for (var i = 0; i < questions.length; i++) ...[
            Text(
              '${i + 1}. ${questions[i].title}',
              style: AppTextStyles.manrope(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 7),
            Text(
              _answer(questions[i].key).isEmpty
                  ? 'Not answered'
                  : _answer(questions[i].key),
              style: AppTextStyles.body(color: AppColors.ink60),
            ),
            if (i < questions.length - 1) ...[
              const SizedBox(height: 14),
              Divider(color: AppColors.ink10),
              const SizedBox(height: 14),
            ],
          ],
        ],
      ),
    );
  }
}
