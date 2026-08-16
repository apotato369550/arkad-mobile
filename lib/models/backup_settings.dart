/// How often [AppState.maybeRunScheduledBackup] is allowed to push a fresh
/// snapshot — checked opportunistically on launch, not via a background task.
enum BackupFrequency { everyLaunch, daily, weekly }

extension BackupFrequencyLabel on BackupFrequency {
  String get label => switch (this) {
        BackupFrequency.everyLaunch => 'Every launch',
        BackupFrequency.daily => 'Daily',
        BackupFrequency.weekly => 'Weekly',
      };

  /// Minimum gap before a backup is due again. [Duration.zero] means "due
  /// whenever the app launches" rather than "due continuously".
  Duration get interval => switch (this) {
        BackupFrequency.everyLaunch => Duration.zero,
        BackupFrequency.daily => const Duration(days: 1),
        BackupFrequency.weekly => const Duration(days: 7),
      };
}

class BackupSettings {
  BackupSettings({this.enabled = false, this.frequency = BackupFrequency.daily, this.lastBackupAt});

  final bool enabled;
  final BackupFrequency frequency;
  final DateTime? lastBackupAt;

  BackupSettings copyWith({
    bool? enabled,
    BackupFrequency? frequency,
    DateTime? lastBackupAt,
    bool clearLastBackupAt = false,
  }) {
    return BackupSettings(
      enabled: enabled ?? this.enabled,
      frequency: frequency ?? this.frequency,
      lastBackupAt: clearLastBackupAt ? null : (lastBackupAt ?? this.lastBackupAt),
    );
  }

  factory BackupSettings.fromJson(Map<String, dynamic> json) {
    return BackupSettings(
      enabled: json['enabled'] as bool? ?? false,
      frequency: BackupFrequency.values.firstWhere(
        (f) => f.name == json['frequency'],
        orElse: () => BackupFrequency.daily,
      ),
      lastBackupAt: json['lastBackupAt'] == null ? null : DateTime.tryParse(json['lastBackupAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'frequency': frequency.name,
        'lastBackupAt': lastBackupAt?.toIso8601String(),
      };
}
