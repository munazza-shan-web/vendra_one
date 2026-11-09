import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backup_restore_card.dart';

class BusinessSettingsScreen extends StatefulWidget {
  const BusinessSettingsScreen({super.key});

  @override
  State<BusinessSettingsScreen> createState() => _BusinessSettingsScreenState();
}

class _BusinessSettingsScreenState extends State<BusinessSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _taxNumber = TextEditingController();
  final _receiptFooter = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _businessName.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _taxNumber.dispose();
    _receiptFooter.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      _businessName.text = preferences.getString('business_name') ?? '';
      _phone.text = preferences.getString('business_phone') ?? '';
      _email.text = preferences.getString('business_email') ?? '';
      _address.text = preferences.getString('business_address') ?? '';
      _taxNumber.text = preferences.getString('business_tax_number') ?? '';
      _receiptFooter.text = preferences.getString('receipt_footer') ?? 'Thank you for shopping with us!';
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load settings: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('business_name', _businessName.text.trim());
      await preferences.setString('business_phone', _phone.text.trim());
      await preferences.setString('business_email', _email.text.trim());
      await preferences.setString('business_address', _address.text.trim());
      await preferences.setString('business_tax_number', _taxNumber.text.trim());
      await preferences.setString('receipt_footer', _receiptFooter.text.trim());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Business settings saved on this device.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save settings: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business settings'),
        actions: [
          IconButton(
            tooltip: 'Save settings',
            onPressed: _loading || _saving ? null : _saveSettings,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.storefront_outlined, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 10),
                            Text('Business profile', style: Theme.of(context).textTheme.titleMedium),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _businessName,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'Business name *',
                                  prefixIcon: Icon(Icons.store_outlined),
                                ),
                                validator: (value) => value == null || value.trim().isEmpty
                                    ? 'Enter your business name'
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _phone,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Business phone',
                                  prefixIcon: Icon(Icons.phone_outlined),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Business email',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                                validator: (value) {
                                  final email = value?.trim() ?? '';
                                  if (email.isNotEmpty && !email.contains('@')) {
                                    return 'Enter a valid email address';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _address,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  labelText: 'Business address',
                                  prefixIcon: Icon(Icons.location_on_outlined),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _taxNumber,
                                decoration: const InputDecoration(
                                  labelText: 'Tax registration number',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.receipt_long_outlined, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 10),
                            Text('Receipt details', style: Theme.of(context).textTheme.titleMedium),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _receiptFooter,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Receipt footer message',
                            hintText: 'Thank you for shopping with us!',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const BackupRestoreCard(),
                const SizedBox(height: 14),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'These business details are saved locally on this device. Cloud sync and multi-device sharing are not enabled.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _saving ? null : _saveSettings,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving...' : 'Save business settings'),
                ),
              ],
            ),
    );
  }
}
