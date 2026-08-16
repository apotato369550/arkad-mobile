import 'package:flutter/material.dart';
import 'app_card.dart';
import '../models/backup_settings.dart';
import '../services/app_state.dart';
import '../services/cloud_backup_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

/// Settings card for cloud backup: on/off, frequency, a manual "back up
/// now", and — separately from the toggle — linking an email so the backup
/// is restorable on a device other than the one that created it (enabling
/// backup alone only creates an anonymous Supabase identity; see
/// [CloudBackupService]'s doc comment).
class CloudBackupCard extends StatefulWidget {
  const CloudBackupCard({super.key, required this.appState});

  final AppState appState;

  @override
  State<CloudBackupCard> createState() => _CloudBackupCardState();
}

class _CloudBackupCardState extends State<CloudBackupCard> {
  late final TextEditingController _emailController;
  late final TextEditingController _codeController;
  bool _busy = false;
  bool _codeSent = false;
  String? _statusMessage;
  bool _statusIsError = false;

  CloudBackupService get _cloudBackup => widget.appState.cloudBackup;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.appState.profile.email.trim());
    _codeController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _setStatus(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _statusIsError = isError;
    });
  }

  Future<void> _toggleEnabled(bool value) async {
    widget.appState.updateBackupSettings(widget.appState.backupSettings.copyWith(enabled: value));
    if (value) await _backUpNow();
  }

  Future<void> _backUpNow() async {
    setState(() => _busy = true);
    try {
      await widget.appState.backUpNow();
      _setStatus('Backed up just now');
    } on CloudBackupException catch (e) {
      _setStatus(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      await widget.appState.restoreFromCloudBackup();
      _setStatus('Restored from cloud backup');
    } on CloudBackupException catch (e) {
      _setStatus(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _cloudBackup.sendEmailCode(email);
      setState(() => _codeSent = true);
      _setStatus('Code sent to $email');
    } on CloudBackupException catch (e) {
      _setStatus(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyCode() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    if (email.isEmpty || code.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _cloudBackup.verifyEmailCode(email: email, code: code);
      setState(() => _codeSent = false);
      _codeController.clear();
      _setStatus('Email linked — this backup can now be restored on any device');
    } on CloudBackupException catch (e) {
      _setStatus(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    if (!_cloudBackup.isConfigured) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_off_outlined, size: 20, color: AppColors.ink),
                const SizedBox(width: 10),
                Text('Cloud backup', style: AppTextStyles.cardHeading()),
              ],
            ),
            const SizedBox(height: 8),
            Text('Not configured for this build.', style: AppTextStyles.metadata()),
          ],
        ),
      );
    }

    final settings = widget.appState.backupSettings;
    final isLinked = _cloudBackup.isLinkedToEmail;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                settings.enabled ? Icons.cloud_done_outlined : Icons.cloud_outlined,
                size: 20,
                color: settings.enabled ? AppColors.darkGreen : AppColors.ink,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('Cloud backup', style: AppTextStyles.cardHeading())),
              Switch(
                value: settings.enabled,
                onChanged: _busy ? null : _toggleEnabled,
                activeThumbColor: AppColors.darkGreen,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Automatically back up your data so it survives a lost or reset device.',
            style: AppTextStyles.metadata(),
          ),
          if (settings.enabled) ...[
            const SizedBox(height: 16),
            Text('Frequency', style: AppTextStyles.metadata()),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final frequency in BackupFrequency.values)
                  _FrequencyChip(
                    label: frequency.label,
                    selected: frequency == settings.frequency,
                    onTap: _busy
                        ? null
                        : () => widget.appState.updateBackupSettings(settings.copyWith(frequency: frequency)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              settings.lastBackupAt == null
                  ? 'Not backed up yet.'
                  : 'Last backed up ${_relativeTime(settings.lastBackupAt!)}.',
              style: AppTextStyles.metadata(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _backUpNow,
                    icon: const Icon(Icons.upload_outlined, size: 18),
                    label: const Text('Back up now'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _restore,
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Restore'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(AppRadii.input)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isLinked) ...[
                    Row(
                      children: [
                        const Icon(Icons.verified_outlined, size: 16, color: AppColors.darkGreen),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Linked to ${_cloudBackup.currentUser?.email}',
                            style: AppTextStyles.metadata(color: AppColors.darkGreen),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Text(
                      'Add an email so you can restore this backup on a new device.',
                      style: AppTextStyles.metadata(),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _emailController,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      style: AppTextStyles.dmMono(),
                      decoration: const InputDecoration(hintText: 'you@example.com', isDense: true),
                    ),
                    if (_codeSent) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _codeController,
                        enabled: !_busy,
                        keyboardType: TextInputType.number,
                        style: AppTextStyles.dmMono(),
                        decoration: const InputDecoration(hintText: '6-digit code', isDense: true),
                      ),
                    ],
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _busy ? null : (_codeSent ? _verifyCode : _sendCode),
                        child: Text(_codeSent ? 'Verify code' : 'Send code'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (_statusMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _statusMessage!,
              style: AppTextStyles.metadata(color: _statusIsError ? AppColors.clay : AppColors.darkGreen),
            ),
          ],
        ],
      ),
    );
  }
}

class _FrequencyChip extends StatelessWidget {
  const _FrequencyChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.darkGreen : AppColors.sageTint,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Text(
          label,
          style: AppTextStyles.manrope(
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.paper : AppColors.ink,
          ),
        ),
      ),
    );
  }
}
