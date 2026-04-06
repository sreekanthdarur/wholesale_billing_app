import 'package:flutter/material.dart';

import '../../data/repositories/item_repository.dart';
import '../../domain/models/invoice_line.dart';
import '../../domain/models/item_model.dart';
import '../../domain/models/missing_item_model.dart';

class MissingItemsPriceDialog extends StatefulWidget {
  final List<MissingItemModel> missingItems;

  const MissingItemsPriceDialog({super.key, required this.missingItems});

  @override
  State<MissingItemsPriceDialog> createState() =>
      _MissingItemsPriceDialogState();
}

class _MissingItemsPriceDialogState extends State<MissingItemsPriceDialog> {
  late final List<TextEditingController> _nameControllers;
  late final List<TextEditingController> _priceControllers;
  late final List<TextEditingController> _qtyControllers;

  late final List<FocusNode> _nameFocusNodes;
  late final List<FocusNode> _qtyFocusNodes;
  late final List<FocusNode> _priceFocusNodes;

  List<ItemModel> _items = [];
  bool _loadingItems = true;
  late final List<String?> _selectedExistingNames;

  @override
  void initState() {
    super.initState();

    _nameControllers = widget.missingItems
        .map((e) => TextEditingController(text: e.itemName))
        .toList();

    _priceControllers = widget.missingItems
        .map(
          (e) => TextEditingController(
            text: e.detectedRate != null && e.detectedRate! > 0
                ? e.detectedRate!.toStringAsFixed(2)
                : '',
          ),
        )
        .toList();

    _qtyControllers = widget.missingItems
        .map(
          (e) => TextEditingController(
            text: e.qty > 0
                ? (e.qty == e.qty.truncateToDouble()
                      ? e.qty.toInt().toString()
                      : e.qty.toString())
                : '1',
          ),
        )
        .toList();

    _nameFocusNodes = List.generate(
      widget.missingItems.length,
      (_) => FocusNode(),
    );
    _qtyFocusNodes = List.generate(
      widget.missingItems.length,
      (_) => FocusNode(),
    );
    _priceFocusNodes = List.generate(
      widget.missingItems.length,
      (_) => FocusNode(),
    );

    _selectedExistingNames = List<String?>.filled(
      widget.missingItems.length,
      null,
    );

    _loadItems();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.missingItems.isEmpty) return;
      _nameFocusNodes.first.requestFocus();
      _nameControllers.first.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _nameControllers.first.text.length,
      );
    });
  }

  Future<void> _loadItems() async {
    final items = await itemRepository.getAll();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loadingItems = false;
    });
  }

  @override
  void dispose() {
    for (final c in _nameControllers) {
      c.dispose();
    }
    for (final c in _priceControllers) {
      c.dispose();
    }
    for (final c in _qtyControllers) {
      c.dispose();
    }
    for (final n in _nameFocusNodes) {
      n.dispose();
    }
    for (final n in _qtyFocusNodes) {
      n.dispose();
    }
    for (final n in _priceFocusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _selectExistingItem(int index, String? itemName) {
    if (itemName == null) return;

    ItemModel? existingItem;
    for (final item in _items) {
      if (item.name == itemName) {
        existingItem = item;
        break;
      }
    }
    if (existingItem == null) return;

    setState(() {
      _selectedExistingNames[index] = existingItem!.name;
      _nameControllers[index].text = existingItem.name;

      final currentPrice =
          double.tryParse(_priceControllers[index].text.trim()) ?? 0;
      if (currentPrice <= 0) {
        _priceControllers[index].text = existingItem.price.toStringAsFixed(2);
      }
    });
  }

  void _focusNextFromName(int index) {
    _qtyFocusNodes[index].requestFocus();
    _qtyControllers[index].selection = TextSelection(
      baseOffset: 0,
      extentOffset: _qtyControllers[index].text.length,
    );
  }

  void _focusNextFromQty(int index) {
    _priceFocusNodes[index].requestFocus();
    _priceControllers[index].selection = TextSelection(
      baseOffset: 0,
      extentOffset: _priceControllers[index].text.length,
    );
  }

  void _focusNextFromPrice(int index) {
    final next = index + 1;
    if (next < widget.missingItems.length) {
      _nameFocusNodes[next].requestFocus();
      _nameControllers[next].selection = TextSelection(
        baseOffset: 0,
        extentOffset: _nameControllers[next].text.length,
      );
    } else {
      FocusScope.of(context).unfocus();
      _submit();
    }
  }

  void _submit() {
    final lines = <InvoiceLineModel>[];

    for (var i = 0; i < widget.missingItems.length; i++) {
      final missing = widget.missingItems[i];
      final itemName = _nameControllers[i].text.trim();
      final qty = double.tryParse(_qtyControllers[i].text.trim()) ?? 0;
      final price = double.tryParse(_priceControllers[i].text.trim()) ?? 0;

      if (itemName.isEmpty || qty <= 0 || price <= 0) {
        continue;
      }

      String unit = missing.unit;

      final selectedName = _selectedExistingNames[i];
      if (selectedName != null) {
        for (final item in _items) {
          if (item.name == selectedName) {
            unit = item.unit;
            break;
          }
        }
      }

      lines.add(
        InvoiceLineModel(
          itemName: itemName,
          qty: qty,
          unit: unit,
          rate: price,
          isCustomRate: true,
          needsReview: false,
          sourceText: missing.sourceText,
        ),
      );
    }

    Navigator.pop(context, lines);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Missing Items'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            children: List.generate(widget.missingItems.length, (index) {
              final item = widget.missingItems[index];

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detected Item ${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameControllers[index],
                      focusNode: _nameFocusNodes[index],
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _focusNextFromName(index),
                      decoration: const InputDecoration(
                        labelText: 'Item Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedExistingNames[index],
                      decoration: const InputDecoration(
                        labelText: 'Select Existing Item (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      items: _loadingItems
                          ? const []
                          : _items
                                .map(
                                  (e) => DropdownMenuItem<String>(
                                    value: e.name,
                                    child: Text(
                                      '${e.name} (₹${e.price.toStringAsFixed(2)}/${e.unit})',
                                    ),
                                  ),
                                )
                                .toList(),
                      onChanged: _loadingItems
                          ? null
                          : (value) => _selectExistingItem(index, value),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _qtyControllers[index],
                            focusNode: _qtyFocusNodes[index],
                            textInputAction: TextInputAction.next,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onSubmitted: (_) => _focusNextFromQty(index),
                            decoration: InputDecoration(
                              labelText: 'Qty (${item.unit})',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _priceControllers[index],
                            focusNode: _priceFocusNodes[index],
                            textInputAction:
                                index == widget.missingItems.length - 1
                                ? TextInputAction.done
                                : TextInputAction.next,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onSubmitted: (_) => _focusNextFromPrice(index),
                            decoration: const InputDecoration(
                              labelText: 'Price',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Source: ${item.sourceText}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, <InvoiceLineModel>[]),
          child: const Text('Skip'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add Items')),
      ],
    );
  }
}
