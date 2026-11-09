
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database/app_database.dart';
import '../../../data/repositories/category_repository.dart';

enum _CategoryFilter { all, active, inactive }

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  final TextEditingController _searchController = TextEditingController();

  _CategoryFilter _filter = _CategoryFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(categoryRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCategoryForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search categories...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _filterChip('All', _CategoryFilter.all),
                const SizedBox(width: 8),
                _filterChip('Active', _CategoryFilter.active),
                const SizedBox(width: 8),
                _filterChip('Inactive', _CategoryFilter.inactive),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<Category>>(
              stream: repository.watchAllCategories(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Unable to load categories.'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final allCategories = snapshot.data ?? [];

                final activeCount =
                    allCategories.where((item) => item.isActive).length;
                final inactiveCount = allCategories.length - activeCount;

                final query = _searchController.text.trim().toLowerCase();

                final categories = allCategories.where((category) {
                  final matchesSearch =
                      category.name.toLowerCase().contains(query);

                  final matchesFilter = switch (_filter) {
                    _CategoryFilter.all => true,
                    _CategoryFilter.active => category.isActive,
                    _CategoryFilter.inactive => !category.isActive,
                  };

                  return matchesSearch && matchesFilter;
                }).toList();

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Text(
                            '$activeCount active',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '$inactiveCount inactive',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${allCategories.length} total',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: categories.isEmpty
                          ? _emptyState()
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                8,
                                16,
                                100,
                              ),
                              itemCount: categories.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final category = categories[index];

                                return _categoryCard(category);
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _CategoryFilter filter) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == filter,
      onSelected: (_) {
        setState(() => _filter = filter);
      },
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.category_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            const Text(
              'No categories found',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text('Try another search or filter.'),
          ],
        ),
      ),
    );
  }

  Widget _categoryCard(Category category) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: category.isActive
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.category_outlined,
            color: category.isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              category.description?.isNotEmpty == true
                  ? category.description!
                  : 'No description',
            ),
            const SizedBox(height: 4),
            Text(
              category.isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                color: category.isActive
                    ? Colors.teal
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'edit') {
              _showCategoryForm(category: category);
            } else if (action == 'deactivate') {
              _changeCategoryStatus(category, activate: false);
            } else if (action == 'activate') {
              _changeCategoryStatus(category, activate: true);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'edit',
              child: Text('Edit'),
            ),
            if (category.isActive)
              const PopupMenuItem(
                value: 'deactivate',
                child: Text('Deactivate'),
              ),
            if (!category.isActive)
              const PopupMenuItem(
                value: 'activate',
                child: Text('Reactivate'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCategoryForm({Category? category}) async {
    final nameController = TextEditingController(
      text: category?.name ?? '',
    );

    final descriptionController = TextEditingController(
      text: category?.description ?? '',
    );

    final formKey = GlobalKey<FormState>();

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(
              category == null ? 'Add Category' : 'Edit Category',
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      autofocus: true,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: 'Category name',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter a category name';
                        }

                        if (value.trim().length > 100) {
                          return 'Maximum 100 characters';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descriptionController,
                      maxLength: 250,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.of(dialogContext).pop(true);
                  }
                },
                child: Text(category == null ? 'Add' : 'Save'),
              ),
            ],
          );
        },
      );

      if (result != true || !mounted) return;

      final repository = ref.read(categoryRepositoryProvider);

      if (category == null) {
        await repository.addCategory(
          name: nameController.text,
          description: descriptionController.text,
        );
      } else {
        await repository.updateCategory(
          id: category.id,
          name: nameController.text,
          description: descriptionController.text,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            category == null
                ? 'Category added successfully.'
                : 'Category updated successfully.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save category: $error'),
        ),
      );
    } finally {
      nameController.dispose();
      descriptionController.dispose();
    }
  }

  Future<void> _changeCategoryStatus(
    Category category, {
    required bool activate,
  }) async {
    final action = activate ? 'reactivate' : 'deactivate';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          activate ? 'Reactivate Category?' : 'Deactivate Category?',
        ),
        content: Text(
          activate
              ? 'Do you want to reactivate "${category.name}"?'
              : 'Do you want to deactivate "${category.name}"? '
                  'Existing products will keep their category history.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(true),
            child: Text(
              activate ? 'Reactivate' : 'Deactivate',
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final repository = ref.read(categoryRepositoryProvider);

      if (activate) {
        await repository.activateCategory(category.id);
      } else {
        await repository.deactivateCategory(category.id);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Category ${activate ? 'reactivated' : 'deactivated'} successfully.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not $action category: $error'),
        ),
      );
    }
  }
}
