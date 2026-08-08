import 'package:flutter/material.dart';
import '../models/api_config.dart';
import '../services/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_card.dart';
import '../widgets/buttons.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  bool _keyVisible = false;

  @override
  void initState() {
    super.initState();
    final config = widget.appState.apiConfig;
    _apiKeyController = TextEditingController(text: config.apiKey ?? '');
    _modelController = TextEditingController(text: config.modelSlug);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  void _saveConnection() {
    widget.appState.updateApiConfig(
      ApiConfig(
        apiKey: _apiKeyController.text.trim().isEmpty ? null : _apiKeyController.text.trim(),
        modelSlug: _modelController.text.trim().isEmpty ? defaultModelSlug : _modelController.text.trim(),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection saved')));
  }

  void _clearKey() {
    _apiKeyController.clear();
    widget.appState.updateApiConfig(widget.appState.apiConfig.copyWith(clearKey: true));
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.modal)),
        title: Text('Clear all data?', style: AppTextStyles.cardHeading()),
        content: Text(
          'This permanently deletes your transactions, categories, profile, and chat history from this device.',
          style: AppTextStyles.body(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Clear everything', style: AppTextStyles.manrope(color: AppColors.clay, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.appState.clearAllData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        Text('Settings', style: AppTextStyles.pageHeading()),
        const SizedBox(height: 20),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('OpenRouter connection', style: AppTextStyles.cardHeading()),
              const SizedBox(height: 8),
              Text(
                'Your key stays on this device and is sent directly to OpenRouter — never to Arkad.',
                style: AppTextStyles.metadata(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _apiKeyController,
                obscureText: !_keyVisible,
                style: AppTextStyles.dmMono(),
                decoration: InputDecoration(
                  labelText: 'OpenRouter API key',
                  suffixIcon: IconButton(
                    icon: Icon(_keyVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    onPressed: () => setState(() => _keyVisible = !_keyVisible),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _modelController,
                style: AppTextStyles.dmMono(),
                decoration: const InputDecoration(labelText: 'Model slug'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: ElevatedButton(onPressed: _saveConnection, child: const Text('Save connection'))),
                  const SizedBox(width: 10),
                  OutlinedButton(onPressed: _clearKey, child: const Text('Clear key')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          color: AppColors.clay.withValues(alpha: 0.08),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Data controls', style: AppTextStyles.cardHeading(color: AppColors.clay)),
              const SizedBox(height: 8),
              Text('Permanently erase everything stored on this device.', style: AppTextStyles.metadata()),
              const SizedBox(height: 16),
              ClayButton(label: 'Clear all data', icon: Icons.delete_forever_outlined, onPressed: _confirmClearAll),
            ],
          ),
        ),
      ],
    );
  }
}
