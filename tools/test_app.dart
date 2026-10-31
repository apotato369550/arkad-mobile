// ignore_for_file: curly_braces_in_flow_control_structures
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  const groups = {
    'onboarding': ['widget_test.dart'],
    'ledger': ['demo_transactions_test.dart'],
    'dashboard': ['cash_flow_range_test.dart', 'dashboard_quiz_card_test.dart'],
    'analysis': ['analysis_state_test.dart'],
    'quiz': ['quiz_synthesis_test.dart', 'spending_style_profile_test.dart'],
    'chat': [
      'openrouter_service_test.dart',
      'chat_features_test.dart',
      'chat_ui_test.dart',
    ],
  };
  if (args.contains('--help')) {
    stdout.writeln(
      'Arkad checks: dart run tools/test_app.dart\n'
      '  --list             List groups\n'
      '  --group analysis   Run one group\n'
      '  --verbose          Print diagnostics as checks run\n'
      '  --web              Also test browser image storage (requires Chrome)',
    );
    return;
  }
  if (args.contains('--list')) {
    stdout.writeln(groups.keys.join('\n'));
    return;
  }
  String? selected;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--verbose' || args[i] == '--web') continue;
    if (args[i] == '--group' && i + 1 < args.length) {
      selected = args[++i];
    } else {
      stderr.writeln('Unknown or incomplete argument: ${args[i]}');
      exitCode = 2;
      return;
    }
  }
  if (selected != null && !groups.containsKey(selected)) {
    stderr.writeln('Unknown group: $selected. Use --list.');
    exitCode = 2;
    return;
  }
  final assigned = groups.values.expand((v) => v).toList();
  final discovered = Directory('test')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('_test.dart'));
  final missing = discovered.where(
    (f) => !assigned.contains(f.uri.pathSegments.last),
  );
  if (missing.isNotEmpty || assigned.toSet().length != assigned.length) {
    stderr.writeln(
      'Test group mapping is incomplete or duplicated: ${missing.map((f) => f.path).join(', ')}',
    );
    exitCode = 2;
    return;
  }
  final directory = Directory('build/test-results/latest')
    ..createSync(recursive: true);
  final report = StringBuffer();
  var failed = false;
  stdout.writeln(
    'Arkad correctness checks\nNo device needed • Mocked AI/cloud • No API charges',
  );
  Future<void> run(String label, String command, List<String> arguments) async {
    stdout.writeln('[RUN ] $label');
    try {
      final result = await Process.run(command, arguments);
      final output = '${result.stdout}\n${result.stderr}';
      File('${directory.path}/$label.log').writeAsStringSync(output);
      report.writeln('$label: exit ${result.exitCode}\n$output');
      if (args.contains('--verbose')) stdout.write(output);
      if (result.exitCode != 0) failed = true;
      stdout.writeln('[${result.exitCode == 0 ? 'PASS' : 'FAIL'}] $label');
      if (result.exitCode != 0)
        stdout.writeln('Details: ${directory.path}/$label.log');
    } on ProcessException catch (error) {
      stderr.writeln(
        'Cannot start $command: $error. Install Flutter and run flutter pub get.',
      );
      exitCode = 2;
      rethrow;
    }
  }

  try {
    await run('code-analysis', 'flutter', ['analyze']);
    for (final entry in groups.entries) {
      if (selected != null && entry.key != selected) continue;
      await run(entry.key, 'flutter', [
        'test',
        '--reporter',
        'json',
        ...entry.value.map((f) => 'test/$f'),
      ]);
      final events = File(
        '${directory.path}/${entry.key}.log',
      ).readAsLinesSync();
      for (final line in events) {
        try {
          final event = jsonDecode(line);
          if (event is Map && event['type'] == 'error')
            stdout.writeln('FAIL: ${event['error']}');
        } on FormatException {
          /* Flutter may emit non-event diagnostics. */
        }
      }
    }
    if (args.contains('--web')) {
      await run('browser', 'flutter', [
        'test',
        '--platform',
        'chrome',
        'browser_test/chat_attachment_browser_test.dart',
      ]);
    } else {
      stdout.writeln(
        '[SKIP] Browser image storage (use --web; requires Chrome)',
      );
    }
    await run('diff-check', 'git', ['diff', '--check']);
  } on ProcessException {
    failed = true;
  } finally {
    File('${directory.path}/report.txt').writeAsStringSync(report.toString());
  }
  if (exitCode != 2) exitCode = failed ? 1 : 0;
  stdout.writeln(
    '${failed ? 'FAILED' : 'PASSED'} — details: ${directory.path}/report.txt',
  );
  stdout.writeln(
    'Does not verify AI advice quality or native device behavior.',
  );
}
