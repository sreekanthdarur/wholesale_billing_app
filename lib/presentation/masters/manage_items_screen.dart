import 'package:flutter/material.dart';
import '../../data/repositories/item_repository.dart';
import '../../domain/models/item_model.dart';

class ManageItemsScreen extends StatefulWidget {
  const ManageItemsScreen({super.key});

  @override
  State<ManageItemsScreen> createState() => _ManageItemsScreenState();
}

class _ManageItemsScreenState extends State<ManageItemsScreen> {
  final nameController = TextEditingController();
  final priceController = TextEditingController();
  final unitController = TextEditingController();
  final aliasController = TextEditingController();

  int? editingId;
  List<ItemModel> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    items = await itemRepository.getAll();
    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> _save() async {
    final name = nameController.text.trim();
    final unit = unitController.text.trim();
    final price = double.tryParse(priceController.text.trim()) ?? 0;
    final aliasesCsv = aliasController.text.trim();

    if (name.isEmpty || unit.isEmpty || price <= 0) return;

    final item = ItemModel(
      id: editingId,
      name: name,
      price: price,
      unit: unit,
      aliasesCsv: aliasesCsv,
    );

    if (editingId == null) {
      await itemRepository.add(item);
    } else {
      await itemRepository.update(item);
    }

    editingId = null;
    nameController.clear();
    priceController.clear();
    unitController.clear();
    aliasController.clear();
    await _load();
  }

  Future<void> _delete(ItemModel item) async {
    await itemRepository.delete(item.id!);
    await _load();
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    unitController.dispose();
    aliasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Items')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Item Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Price',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: unitController,
                          decoration: const InputDecoration(
                            labelText: 'Unit',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: aliasController,
                    decoration: const InputDecoration(
                      labelText: 'Aliases (comma separated)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _save,
                    child: Text(
                      editingId == null ? 'Save Item' : 'Update Item',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (_, index) {
                        final item = items[index];
                        return Card(
                          child: ListTile(
                            title: Text(item.name),
                            subtitle: Text(
                              '₹${item.price.toStringAsFixed(2)} / ${item.unit}'
                              '${item.aliasesCsv.trim().isEmpty ? '' : '\nAliases: ${item.aliasesCsv}'}',
                            ),
                            isThreeLine: item.aliasesCsv.trim().isNotEmpty,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () => setState(() {
                                    editingId = item.id;
                                    nameController.text = item.name;
                                    priceController.text = item.price
                                        .toStringAsFixed(2);
                                    unitController.text = item.unit;
                                    aliasController.text = item.aliasesCsv;
                                  }),
                                  icon: const Icon(Icons.edit),
                                ),
                                IconButton(
                                  onPressed: () => _delete(item),
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
