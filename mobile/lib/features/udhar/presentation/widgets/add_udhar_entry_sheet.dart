import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/udhar/presentation/providers/udhar_dashboard_provider.dart';
import 'package:mobile/features/udhar/presentation/providers/udhar_provider.dart';
import 'package:mobile/features/inventory/presentation/providers/vendor_ledger_provider.dart';

class AddUdharEntrySheet extends ConsumerStatefulWidget {
  const AddUdharEntrySheet({super.key});

  @override
  ConsumerState<AddUdharEntrySheet> createState() => _AddUdharEntrySheetState();
}

class _AddUdharEntrySheetState extends ConsumerState<AddUdharEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _partyNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String _partyType = 'customer'; // 'customer' or 'vendor'
  String _entryType = 'got'; // 'got' or 'gave'
  bool _isLoading = false;

  @override
  void dispose() {
    _partyNameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final amount = double.parse(_amountController.text);
      if (amount <= 0) {
        throw Exception('Amount must be greater than zero');
      }

      final response = await ApiClient().dio.post(
        '/api/udhar/manual-entry',
        data: {
          'party_type': _partyType,
          'party_name': _partyNameController.text.trim(),
          'amount': amount,
          'entry_type': _entryType,
          'notes': _notesController.text.trim(),
        },
      );

      if (response.data['status'] == 'success') {
        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Entry added successfully')),
          );
        }
        
        // Refresh relevant lists and dashboard
         ref.read(udharDashboardProvider.notifier).fetchSummary();
        if (_partyType == 'customer') {
           ref.read(udharProvider.notifier).fetchLedgers();
        } else {
           ref.read(vendorLedgerProvider.notifier).fetchLedgers();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add entry: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine colors based on entry type to match conventions
    // 'got' (You Got) is usually Green in cashbooks, 'gave' (You Gave) is Red
    final bool isGot = _entryType == 'got';
    final Color activeColor = isGot ? Colors.green : Colors.red;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'New Credit Entry',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Party Type Toggle
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'customer',
                      label: Text('Customer'),
                      icon: Icon(Icons.person),
                    ),
                    ButtonSegment(
                      value: 'vendor',
                      label: Text('Supplier'),
                      icon: Icon(Icons.local_shipping),
                    ),
                  ],
                  selected: {_partyType},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _partyType = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 24),

                // Party Name
                TextFormField(
                  controller: _partyNameController,
                  decoration: InputDecoration(
                    labelText: _partyType == 'customer' ? 'Customer Name' : 'Supplier Name',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Amount
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.currency_rupee),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an amount';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    if (double.parse(value) <= 0) {
                      return 'Amount must be greater than zero';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Entry Type (Got / Gave) Toggle
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _entryType = 'got'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _entryType == 'got' ? Colors.green.shade100 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _entryType == 'got' ? Colors.green : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.arrow_downward, color: _entryType == 'got' ? Colors.green : Colors.grey),
                              const SizedBox(height: 4),
                              Text(
                                'You Got',
                                style: TextStyle(
                                  color: _entryType == 'got' ? Colors.green : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _entryType = 'gave'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _entryType == 'gave' ? Colors.red.shade100 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _entryType == 'gave' ? Colors.red : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.arrow_upward, color: _entryType == 'gave' ? Colors.red : Colors.grey),
                              const SizedBox(height: 4),
                              Text(
                                'You Gave',
                                style: TextStyle(
                                  color: _entryType == 'gave' ? Colors.red : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Notes
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Save Entry',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
