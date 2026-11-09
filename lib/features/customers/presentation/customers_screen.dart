import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database/app_database.dart';
import '../../../data/repositories/customer_repository.dart';

String _money(int minor) => 'Rs ' + (minor / 100).toStringAsFixed(2);

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _editCustomer({Customer? customer}) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: customer?.name ?? '');
    final phone = TextEditingController(text: customer?.phone ?? '');
    final email = TextEditingController(text: customer?.email ?? '');
    final address = TextEditingController(text: customer?.address ?? '');
    final notes = TextEditingController(text: customer?.notes ?? '');
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(customer == null ? 'Add customer' : 'Edit customer'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Name *'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Customer name is required'
                              : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) {
                        final valueText = value?.trim() ?? '';
                        return valueText.isNotEmpty && !valueText.contains('@')
                            ? 'Enter a valid email'
                            : null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: address,
                      decoration: const InputDecoration(labelText: 'Address'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: notes,
                      decoration: const InputDecoration(labelText: 'Notes'),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => saving = true);
                      try {
                        final repo = ref.read(customerRepositoryProvider);
                        if (customer == null) {
                          await repo.addCustomer(
                            name: name.text,
                            phone: phone.text,
                            email: email.text,
                            address: address.text,
                            notes: notes.text,
                          );
                        } else {
                          await repo.updateCustomer(
                            id: customer.id,
                            name: name.text,
                            phone: phone.text,
                            email: email.text,
                            address: address.text,
                            notes: notes.text,
                          );
                        }
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(customer == null
                                  ? 'Customer added'
                                  : 'Customer updated'),
                            ),
                          );
                        }
                      } catch (error) {
                        setDialogState(() => saving = false);
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(content: Text('Unable to save: ' + error.toString())),
                        );
                      }
                    },
              child: Text(saving ? 'Saving...' : 'Save customer'),
            ),
          ],
        ),
      ),
    );

    name.dispose();
    phone.dispose();
    email.dispose();
    address.dispose();
    notes.dispose();
  }

  Future<void> _archive(Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive customer?'),
        content: Text(
          'Archive ' + customer.name +
              '? Existing sales history will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(customerRepositoryProvider).deactivateCustomer(customer.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer archived')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to archive: ' + error.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(customerRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          IconButton(
            tooltip: 'Add customer',
            onPressed: () => _editCustomer(),
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editCustomer(),
        icon: const Icon(Icons.add),
        label: const Text('Add customer'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search name, phone or email',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.clear),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Customer>>(
              stream: repository.watchCustomers(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Unable to load customers.'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snapshot.data!;
                final visible = all.where((customer) {
                  if (_query.isEmpty) return true;
                  return customer.name.toLowerCase().contains(_query) ||
                      (customer.phone?.toLowerCase().contains(_query) ?? false) ||
                      (customer.email?.toLowerCase().contains(_query) ?? false);
                }).toList();

                if (all.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.people_outline, size: 60),
                          const SizedBox(height: 12),
                          Text('No customers yet',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          const Text(
                            'Add customers to save contact details and track outstanding balances.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => _editCustomer(),
                            icon: const Icon(Icons.add),
                            label: const Text('Add first customer'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (visible.isEmpty) {
                  return const Center(child: Text('No matching customers.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final customer = visible[index];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        leading: CircleAvatar(
                          child: Text(customer.name.substring(0, 1).toUpperCase()),
                        ),
                        title: Text(customer.name,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (customer.phone?.isNotEmpty == true)
                              Text(customer.phone!),
                            if (customer.email?.isNotEmpty == true)
                              Text(customer.email!),
                            const SizedBox(height: 4),
                            FutureBuilder<int>(
                              future: repository.getOutstandingBalance(customer.id),
                              builder: (context, balance) => Text(
                                'Outstanding: ' +
                                    _money(balance.data ?? 0),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: (balance.data ?? 0) > 0
                                      ? Theme.of(context).colorScheme.error
                                      : null,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _editCustomer(customer: customer);
                            } else {
                              _archive(customer);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            PopupMenuItem(
                              value: 'archive',
                              child: Text('Archive'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
