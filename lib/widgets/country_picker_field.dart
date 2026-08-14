import 'package:flutter/material.dart';
import '../models/countries.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

/// Tap target that opens a searchable bottom sheet of [countries], each row
/// showing its flag next to its name. Used by onboarding and Settings so
/// country (and therefore currency) selection looks and behaves the same
/// everywhere.
class CountryPickerField extends StatelessWidget {
  const CountryPickerField({
    super.key,
    required this.countryCode,
    required this.onChanged,
    this.hintText = 'Select your country',
  });

  final String countryCode;
  final ValueChanged<String> onChanged;
  final String hintText;

  Future<void> _open(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.paper,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.modal)),
      ),
      builder: (context) => _CountryPickerSheet(initialCode: countryCode),
    );
    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final selectedCountry = countryCode.isEmpty ? null : countryNameForCode(countryCode);
    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(AppRadii.input),
          border: Border.all(color: AppColors.ink10),
        ),
        child: Row(
          children: [
            if (selectedCountry != null) ...[
              Text(countries.firstWhere((c) => c.code == countryCode).flag,
                  style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                selectedCountry ?? hintText,
                style: selectedCountry != null
                    ? AppTextStyles.manrope(fontWeight: FontWeight.w600)
                    : AppTextStyles.manrope(color: AppColors.ink40),
              ),
            ),
            Icon(Icons.expand_more, color: AppColors.ink40),
          ],
        ),
      ),
    );
  }
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({required this.initialCode});

  final String initialCode;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  late List<Country> _filtered;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = countries;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _filtered = query.trim().isEmpty
          ? countries
          : countries
              .where((c) => c.name.toLowerCase().contains(query.trim().toLowerCase()))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: AppColors.ink10, borderRadius: BorderRadius.circular(AppRadii.pill)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(
                    hintText: 'Search countries',
                    prefixIcon: Icon(Icons.search, size: 20),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  itemCount: _filtered.length,
                  itemBuilder: (context, index) {
                    final country = _filtered[index];
                    final isSelected = country.code == widget.initialCode;
                    return ListTile(
                      onTap: () => Navigator.of(context).pop(country.code),
                      leading: Text(country.flag, style: const TextStyle(fontSize: 22)),
                      title: Text(country.name, style: AppTextStyles.manrope(fontWeight: FontWeight.w600)),
                      trailing: isSelected ? Icon(Icons.check, color: AppColors.darkGreen) : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
