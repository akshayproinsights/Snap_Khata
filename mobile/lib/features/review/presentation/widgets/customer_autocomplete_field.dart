import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../udhar/domain/models/udhar_models.dart';
import '../../../udhar/presentation/providers/udhar_provider.dart';

class CustomerAutocompleteField extends ConsumerStatefulWidget {
  final String initialValue;
  final ValueChanged<String> onSaved;
  final ValueChanged<CustomerLedger>? onCustomerSelected;
  final String label;

  const CustomerAutocompleteField({
    super.key,
    required this.initialValue,
    required this.onSaved,
    this.onCustomerSelected,
    required this.label,
  });

  @override
  ConsumerState<CustomerAutocompleteField> createState() =>
      _CustomerAutocompleteFieldState();
}

class _CustomerAutocompleteFieldState
    extends ConsumerState<CustomerAutocompleteField> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;
  bool _isNew = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _checkIfNew(widget.initialValue);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _save();
    }
  }

  void _save() {
    final val = _controller.text.trim();
    widget.onSaved(val);
  }

  void _checkIfNew(String value) {
    if (value.isEmpty) {
      if (_isNew) setState(() => _isNew = false);
      return;
    }

    final ledgers = ref.read(udharProvider).ledgers;
    final exists = ledgers.any((l) =>
        l.customerName.trim().toLowerCase() == value.trim().toLowerCase());

    if (_isNew == exists) {
      setState(() => _isNew = !exists);
    }
  }

  void _onChanged(String value) {
    _checkIfNew(value);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _save();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ledgers = ref.watch(udharProvider).ledgers;

    return Autocomplete<CustomerLedger>(
      displayStringForOption: (option) => option.customerName,
      initialValue: TextEditingValue(text: widget.initialValue),
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<CustomerLedger>.empty();
        }
        return ledgers.where((CustomerLedger option) {
          return option.customerName
              .toLowerCase()
              .contains(textEditingValue.text.toLowerCase());
        });
      },
      onSelected: (CustomerLedger selection) {
        _controller.text = selection.customerName;
        _checkIfNew(selection.customerName);
        if (widget.onCustomerSelected != null) {
          widget.onCustomerSelected!(selection);
        }
        _save();
      },
      fieldViewBuilder:
          (context, textController, focusNode, onFieldSubmitted) {
        // Sync our local controller and state
        if (_controller.text != textController.text && _controller.text.isEmpty && textController.text.isNotEmpty) {
           _controller.text = textController.text;
        }
        
        textController.addListener(() {
          if (_controller.text != textController.text) {
             _controller.text = textController.text;
             _onChanged(textController.text);
          }
        });

        return TextField(
          controller: textController,
          focusNode: focusNode,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: TextStyle(fontSize: 12, color: context.textSecondaryColor),
            filled: true,
            fillColor: context.surfaceColor,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.primaryColor, width: 1.5),
            ),
            suffixIcon: _isNew && _controller.text.isNotEmpty
                ? Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.userPlus, size: 10, color: context.primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          'New',
                          style: TextStyle(
                            color: context.primaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                : const Icon(LucideIcons.chevronDown, size: 16),
            suffixIconConstraints: const BoxConstraints(minHeight: 0, minWidth: 0),
          ),
          onSubmitted: (val) {
            _save();
            onFieldSubmitted();
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            color: context.surfaceColor,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.7,
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                border: Border.all(color: context.borderColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (context, i) => Divider(height: 1, color: context.borderColor),
                itemBuilder: (BuildContext context, int index) {
                  final CustomerLedger option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(option.customerName, 
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: option.customerPhone != null 
                      ? Text(option.customerPhone!, style: TextStyle(fontSize: 11, color: context.textSecondaryColor))
                      : null,
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
