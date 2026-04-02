import 'package:flutter/material.dart';
import '../../data/repositories/customer_repository.dart';
import '../../domain/models/customer_model.dart';

class ManageCustomersScreen extends StatefulWidget {
  const ManageCustomersScreen({super.key});

  @override
  State<ManageCustomersScreen> createState() => _ManageCustomersScreenState();
}

class _ManageCustomersScreenState extends State<ManageCustomersScreen> {
  final controller = TextEditingController();
  int? editingId;
  List<CustomerModel> customers = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    customers = await customerRepository.getAll();
    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> _save() async {
    final value = controller.text.trim();
    if (value.isEmpty) return;

    if (editingId == null) {
      await customerRepository.add(value);
    } else {
      await customerRepository.update(editingId!, value);
    }

    controller.clear();
    editingId = null;
    await _load();
  }

  Future<void> _delete(CustomerModel customer) async {
    if (customer.name.toLowerCase() == 'cash') return;
    await customerRepository.delete(customer.id!);
    await _load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Customers')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Customer Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _save,
                    child: Text(
                      editingId == null ? 'Save Customer' : 'Update Customer',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: customers.length,
                      itemBuilder: (_, index) {
                        final customer = customers[index];
                        return Card(
                          child: ListTile(
                            title: Text(customer.name),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () => setState(() {
                                    editingId = customer.id;
                                    controller.text = customer.name;
                                  }),
                                  icon: const Icon(Icons.edit),
                                ),
                                IconButton(
                                  onPressed: () => _delete(customer),
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
