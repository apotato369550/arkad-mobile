import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_card.dart';
import '../services/app_state.dart';
import '../services/export_service.dart';
import '../services/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

/// Settings card: pick a date range, then email a text export of the
/// transactions and saved AI analyses in that range to the address set on
/// the Profile tab. Sent via a `mailto:` handoff to the device's mail
/// app — Arkad has no backend of its own to send mail from (see
/// STYLE_GUIDE.md § OpenRouter connection for the same local-only stance
/// on the OpenRouter key).
class ExportDataCard extends StatefulWidget {
  const ExportDataCard({super.key, required this.appState});

  final AppState appState;

  @override
  State<ExportDataCard> createState() => _ExportDataCardState();
}

class _ExportDataCardState extends State<ExportDataCard> {
  late DateTimeRange _range;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(start: DateTime(now.year, now.month - 1, now.day), end: now);
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _emailExport() async {
    final email = widget.appState.profile.email.trim();
    if (email.isEmpty) return;

    final body = buildExportEmailBody(
      range: _range,
      transactions: widget.appState.transactionsInRange(_range),
      analyses: widget.appState.savedAnalysesInRange(_range),
    );
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query: Uri(queryParameters: {
        'subject': 'Arkad export: ${formatMDY(_range.start)} - ${formatMDY(_range.end)}',
        'body': body,
      }).query,
    );

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('No mail app available to open')));
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not open mail app')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.appState.profile.email.trim();
    final transactionCount = widget.appState.transactionsInRange(_range).length;
    final analysisCount = widget.appState.savedAnalysesInRange(_range).length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Export data', style: AppTextStyles.cardHeading()),
          const SizedBox(height: 8),
          Text(
            'Email your transactions and saved AI analyses for a date range.',
            style: AppTextStyles.metadata(),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _pickRange,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(AppRadii.input)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${formatMDY(_range.start)} – ${formatMDY(_range.end)}', style: AppTextStyles.dmMono()),
                  const Icon(Icons.calendar_today_outlined, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$transactionCount transaction${transactionCount == 1 ? '' : 's'}, '
            '$analysisCount saved ${analysisCount == 1 ? 'analysis' : 'analyses'} in this range.',
            style: AppTextStyles.metadata(),
          ),
          const SizedBox(height: 16),
          if (email.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Add your email on the Profile tab to enable this.', style: AppTextStyles.metadata(color: AppColors.clay)),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Sends to $email', style: AppTextStyles.metadata()),
            ),
          ElevatedButton.icon(
            onPressed: email.isEmpty ? null : _emailExport,
            icon: const Icon(Icons.email_outlined, size: 18),
            label: const Text('Email export'),
          ),
        ],
      ),
    );
  }
}
