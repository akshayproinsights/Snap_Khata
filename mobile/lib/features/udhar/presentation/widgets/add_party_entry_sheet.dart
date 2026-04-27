import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:mobile/features/udhar/presentation/providers/udhar_provider.dart';
import 'package:mobile/features/inventory/presentation/providers/vendor_ledger_provider.dart';
import 'package:mobile/core/theme/context_extension.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AddPartyEntrySheet extends ConsumerStatefulWidget {
  const AddPartyEntrySheet({super.key});

  @override
  ConsumerState<AddPartyEntrySheet> createState() => _AddPartyEntrySheetState();
}

class _AddPartyEntrySheetState extends ConsumerState<AddPartyEntrySheet> {
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
            const SnackBar(content: Text('Entry added successfully! 🎉')),
          );
        }
        
        // Refresh relevant lists and dashboard
        ref.read(dashboardTotalsProvider.notifier).refresh();
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
    final bool isGot = _entryType == 'got';
    final Color activeColor = isGot ? context.successColor : context.errorColor;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 12,
      ),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: context.borderColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Record Transaction',
                      style: TextStyle(
                        fontSize: 24, 
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: context.borderColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.x, size: 20),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Party Type Toggle
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: context.borderColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TypeToggle(
                          label: 'Customer',
                          isSelected: _partyType == 'customer',
                          onTap: () => setState(() => _partyType = 'customer'),
                          icon: LucideIcons.user,
                        ),
                      ),
                      Expanded(
                        child: _TypeToggle(
                          label: 'Supplier',
                          isSelected: _partyType == 'vendor',
                          onTap: () => setState(() => _partyType = 'vendor'),
                          icon: LucideIcons.truck,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),

                // Party Name
                TextFormField(
                  controller: _partyNameController,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    labelText: _partyType == 'customer' ? 'Customer Name' : 'Supplier Name',
                    hintText: 'Who are you dealing with?',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    prefixIcon: const Icon(LucideIcons.userPlus, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  decoration: InputDecoration(
                    labelText: 'Amount (₹)',
                    hintText: '0.00',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    prefixIcon: const Icon(LucideIcons.indianRupee, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
                      child: _EntryTypeButton(
                        label: 'YOU GOT',
                        isSelected: _entryType == 'got',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _entryType = 'got');
                        },
                        activeColor: context.successColor,
                        icon: LucideIcons.arrowDownLeft,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _EntryTypeButton(
                        label: 'YOU GAVE',
                        isSelected: _entryType == 'gave',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _entryType = 'gave');
                        },
                        activeColor: context.errorColor,
                        icon: LucideIcons.arrowUpRight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Notes
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: 'Notes (Optional)',
                    hintText: 'Bill number, item details etc.',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    prefixIcon: const Icon(LucideIcons.pencil, size: 20),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 32),

                // Submit Button
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [activeColor, activeColor.withValues(alpha: 0.8)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                          )
                        : const Text(
                            'SAVE TRANSACTION',
                            style: TextStyle(
                              fontSize: 16, 
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData icon;

  const _TypeToggle({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? context.surfaceColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ] : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon, 
              size: 16, 
              color: isSelected ? context.primaryColor : context.textSecondaryColor
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? context.textColor : context.textSecondaryColor,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryTypeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color activeColor;
  final IconData icon;

  const _EntryTypeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.activeColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.08) : context.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : context.borderColor.withValues(alpha: 0.5),
            width: isSelected ? 2.5 : 1.5,
          ),
          gradient: isSelected ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              activeColor.withValues(alpha: 0.12),
              activeColor.withValues(alpha: 0.02),
            ],
          ) : null,
          boxShadow: isSelected ? [
            BoxShadow(
              color: activeColor.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ] : null,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? activeColor.withValues(alpha: 0.1) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon, 
                color: isSelected ? activeColor : context.textSecondaryColor,
                size: 26,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : context.textSecondaryColor,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
