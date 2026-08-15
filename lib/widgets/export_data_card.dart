import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'app_card.dart';
import '../services/app_state.dart';
import '../services/export_service.dart';
import '../services/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

/// Settings card: pick a date range, then share a formatted, tabular PDF of
/// the transactions and saved AI analyses in that range — via the OS share
/// sheet, so it can be attached to an email addressed to the address set on
/// the Profile tab. Arkad has no backend of its own to send mail from (see
/// STYLE_GUIDE.md § OpenRouter connection for the same local-only stance on
/// the OpenRouter key), so sharing to Mail is a manual last step rather than
/// a silent server-side send.
class ExportDataCard extends StatefulWidget {
  const ExportDataCard({super.key, required this.appState});

  final AppState appState;

  @override
  State<ExportDataCard> createState() => _ExportDataCardState();
}

class _ExportDataCardState extends State<ExportDataCard> {
  late DateTimeRange _range;
  bool _generating = false;

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

  Future<void> _shareExport() async {
    setState(() => _generating = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final (totalIncome, totalExpense) = widget.appState.totalsForDateRange(_range);
      final bytes = await buildExportPdf(
        range: _range,
        transactions: widget.appState.transactionsInRange(_range),
        analyses: widget.appState.savedAnalysesInRange(_range),
        totalIncome: totalIncome,
        totalExpense: totalExpense,
      );
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'arkad-export-${_fileDate(_range.start)}-${_fileDate(_range.end)}.pdf',
      );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not generate the export')));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  String _fileDate(DateTime date) =>
      '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';

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
            'Generate a PDF of your transactions and saved AI analyses for a date range.',
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
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              email.isEmpty
                  ? 'Add your email on the Profile tab so you know where to send it.'
                  : 'Share the PDF to Mail, addressed to $email.',
              style: AppTextStyles.metadata(color: email.isEmpty ? AppColors.clay : null),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _generating ? null : _shareExport,
            icon: _generating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.paper),
                  )
                : const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: Text(_generating ? 'Preparing PDF…' : 'Share PDF export'),
          ),
        ],
      ),
    );
  }
}
