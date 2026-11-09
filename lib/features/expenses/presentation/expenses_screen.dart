import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/repositories/expense_repository.dart';

String _money(int minor) => 'Rs ' + (minor / 100).toStringAsFixed(2);

String _paymentLabel(String method) {
  return method.replaceAll('_', ' ').split(' ').map((word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1);
  }).join(' ');
}

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  Future<void> _addExpense(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final amount = TextEditingController();
    final reference = TextEditingController();
    final notes = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var category = ExpenseRepository.categories.first;
    var paymentMethod = 'cash';
    var expenseDate = DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add expense'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: title,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Expense title *'),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Enter an expense title'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: ExpenseRepository.categories
                          .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setDialogState(() => category = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Amount (Rs) *'),
                      validator: (value) {
                        final parsed = double.tryParse(value?.trim() ?? '');
                        if (parsed == null || !parsed.isFinite || parsed <= 0) {
                          return 'Enter an amount greater than zero';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: paymentMethod,
                      decoration: const InputDecoration(labelText: 'Payment method'),
                      items: ExpenseRepository.paymentMethods
                          .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text(_paymentLabel(value)),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setDialogState(() => paymentMethod = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Expense date'),
                      subtitle: Text(DateFormat('d MMM yyyy').format(expenseDate)),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: () async {
                        final selected = await showDatePicker(
                          context: context,
                          initialDate: expenseDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (selected != null) {
                          setDialogState(() => expenseDate = selected);
                        }
                      },
                    ),
                    TextField(
                      controller: reference,
                      decoration: const InputDecoration(labelText: 'Reference (optional)'),
                    ),
                    TextField(
                      controller: notes,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Notes (optional)'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final parsedAmount = double.parse(amount.text.trim());
                try {
                  await ref.read(expenseRepositoryProvider).addExpense(
                    title: title.text,
                    category: category,
                    amountMinor: (parsedAmount * 100).round(),
                    paymentMethod: paymentMethod,
                    expenseDate: expenseDate,
                    reference: reference.text,
                    notes: notes.text,
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Expense saved')),
                    );
                  }
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not save expense: $error')),
                    );
                  }
                }
              },
              child: const Text('Save expense'),
            ),
          ],
        ),
      ),
    );

    title.dispose();
    amount.dispose();
    reference.dispose();
    notes.dispose();
  }

  Future<void> _deleteExpense(
    BuildContext context,
    WidgetRef ref,
    ExpenseRecord expense,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text('Delete "${expense.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(expenseRepositoryProvider).deleteExpense(expense.id);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete expense: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(expenseRepositoryProvider);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final nextMonth = DateTime(now.year, now.month + 1);

    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addExpense(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
      ),
      body: StreamBuilder<List<ExpenseRecord>>(
        stream: repository.watchExpenses(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load expenses.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final expenses = snapshot.data!;
          final monthExpenses = expenses.where((expense) {
            return !expense.expenseDate.isBefore(monthStart) &&
                expense.expenseDate.isBefore(nextMonth);
          }).toList();
          final monthTotal = monthExpenses.fold<int>(
            0,
            (total, expense) => total + expense.amountMinor,
          );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          child: Icon(Icons.account_balance_wallet_outlined),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(DateFormat('MMMM yyyy').format(now) + ' expenses'),
                              const SizedBox(height: 4),
                              Text(
                                _money(monthTotal),
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Text(monthExpenses.length.toString() + ' records'),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: expenses.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 60),
                              SizedBox(height: 12),
                              Text('No expenses recorded', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                              SizedBox(height: 8),
                              Text('Record rent, utilities, salaries and other business expenses.', textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: expenses.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final expense = expenses[index];
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.payments_outlined),
                              ),
                              title: Text(
                                expense.title,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '${expense.category} • ${DateFormat('d MMM yyyy').format(expense.expenseDate)}\n'
                                '${_paymentLabel(expense.paymentMethod)}'
                                '${expense.reference == null ? '' : ' • ${expense.reference}'}',
                              ),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _money(expense.amountMinor),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'delete') {
                                        _deleteExpense(context, ref, expense);
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
