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
  final bool hasError;
  /// When true, shows the full list of recent customers when field is focused
  /// even without any typed text. Best for the top-of-page banner usage.
  final bool showOnFocus;
  /// Compact mode: single-line style for use inside header card.
  final bool compact;

  const CustomerAutocompleteField({
    super.key,
    required this.initialValue,
    required this.onSaved,
    this.onCustomerSelected,
    required this.label,
    this.hasError = false,
    this.showOnFocus = true,
    this.compact = false,
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
  CustomerLedger? _selectedParty;
  bool _isFocused = false;
  // Track the last name that was explicitly selected from the dropdown.
  // If the user edits the text away from this value we immediately clear the
  // selection so the receipt is NOT silently merged into an existing ledger.
  String? _lastExplicitlySelectedName;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode.addListener(_onFocusChange);
    // Try to match initial value to an existing party after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _matchInitialParty(widget.initialValue);
    });
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
    setState(() => _isFocused = _focusNode.hasFocus);
    if (!_focusNode.hasFocus) {
      _save();
    }
  }

  void _save() {
    final val = _controller.text.trim();
    widget.onSaved(val);
  }

  void _matchInitialParty(String value) {
    if (value.isEmpty) return;
    final ledgers = ref.read(udharProvider).ledgers;
    // STRICT: only an exact (case-insensitive) match counts as an existing party.
    final match = ledgers.where((l) =>
        l.customerName.trim().toLowerCase() == value.trim().toLowerCase()).firstOrNull;
    if (match != null && mounted) {
      setState(() {
        _selectedParty = match;
        _lastExplicitlySelectedName = match.customerName;
        _isNew = false;
      });
    } else if (value.isNotEmpty && mounted) {
      setState(() => _isNew = true);
    }
  }

  void _checkIfNew(String value) {
    if (value.isEmpty) {
      if (_isNew || _selectedParty != null) {
        setState(() {
          _isNew = false;
          _selectedParty = null;
          _lastExplicitlySelectedName = null;
        });
      }
      return;
    }

    // ── Guard: if user edits text away from the explicitly selected name,
    // clear the selection immediately so the receipt is treated as a NEW customer
    // or re-matched by exact name — never silently merged.
    if (_lastExplicitlySelectedName != null &&
        value.trim().toLowerCase() != _lastExplicitlySelectedName!.toLowerCase()) {
      _lastExplicitlySelectedName = null;
      setState(() {
        _selectedParty = null;
        _isNew = true; // will be corrected by exact-match check below
      });
    }

    // STRICT: only exact (case-insensitive) match → existing party.
    final ledgers = ref.read(udharProvider).ledgers;
    final match = ledgers.where((l) =>
        l.customerName.trim().toLowerCase() == value.trim().toLowerCase()).firstOrNull;

    setState(() {
      _selectedParty = match;
      if (match != null) {
        _lastExplicitlySelectedName = match.customerName;
      }
      _isNew = match == null;
    });
  }

  void _onChanged(String value) {
    _checkIfNew(value);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _save();
    });
  }

  /// Splits [query] into words and returns true only if every word in the query
  /// is found as a case-insensitive **prefix** of at least one word in [name].
  /// This prevents "Deshmukh" from showing when the user has typed "Deshmukh 123"
  /// (since "123" is not a prefix of any word in "Deshmukh").
  bool _matchesQuery(String name, String query) {
    if (query.isEmpty) return true;
    final nameLower = name.toLowerCase();
    final queryWords = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final nameWords = nameLower.split(RegExp(r'\s+'));
    for (final qWord in queryWords) {
      // Each query word must be a prefix of at least one word in the name
      final found = nameWords.any((nWord) => nWord.startsWith(qWord));
      if (!found) return false;
    }
    return true;
  }

  String _formatBalance(double balance) {
    if (balance <= 0) return '₹0';
    if (balance >= 1000) return '₹${(balance / 1000).toStringAsFixed(1)}k';
    return '₹${balance.toStringAsFixed(0)}';
  }

  String _formatLastVisit(CustomerLedger party) {
    final date = party.updatedAt ?? party.latestBillDate ?? party.latestUploadDate;
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '${diff}d ago';
    if (diff < 30) return '${(diff / 7).floor()}w ago';
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${date.day} ${months[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final ledgers = ref.watch(udharProvider).ledgers;

    // Sort by most recently updated
    final sortedLedgers = List<CustomerLedger>.from(ledgers)
      ..sort((a, b) {
        final aDate = a.updatedAt ?? a.latestBillDate ?? DateTime(2000);
        final bDate = b.updatedAt ?? b.latestBillDate ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });

    return Autocomplete<CustomerLedger>(
      displayStringForOption: (option) => option.customerName,
      initialValue: TextEditingValue(text: widget.initialValue),
      optionsBuilder: (TextEditingValue textEditingValue) {
        // Show all recents on focus (empty text) if showOnFocus is enabled
        if (textEditingValue.text.isEmpty) {
          if (widget.showOnFocus && _isFocused) {
            return sortedLedgers.take(8);
          }
          return const Iterable<CustomerLedger>.empty();
        }
        // STRICT word-prefix matching: every word in the query must be a prefix
        // of at least one word in the candidate name.
        // Example: query="Deshmukh 123" → "Deshmukh" is NOT shown because "123"
        // is not a prefix of any word in "Deshmukh".
        return sortedLedgers.where((CustomerLedger option) {
          return _matchesQuery(option.customerName, textEditingValue.text);
        });
      },
      onSelected: (CustomerLedger selection) {
        // User explicitly tapped an existing party from the dropdown.
        // Record the name so we can detect if they later edit the text.
        _controller.text = selection.customerName;
        _lastExplicitlySelectedName = selection.customerName;
        setState(() {
          _selectedParty = selection;
          _isNew = false;
        });
        if (widget.onCustomerSelected != null) {
          widget.onCustomerSelected!(selection);
        }
        _save();
      },
      fieldViewBuilder:
          (context, textController, focusNode, onFieldSubmitted) {
        // Sync our local controller with Autocomplete's internal controller
        if (_controller.text != textController.text &&
            _controller.text.isEmpty &&
            textController.text.isNotEmpty) {
          _controller.text = textController.text;
        }

        textController.addListener(() {
          if (_controller.text != textController.text) {
            _controller.text = textController.text;
            _onChanged(textController.text);
          }
        });

        final border = OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.compact ? 8 : 14),
          borderSide: BorderSide(
            color: widget.hasError
                ? context.errorColor
                : (_selectedParty != null
                    ? context.successColor
                    : context.borderColor),
            width: widget.hasError ? 1.5 : (_selectedParty != null ? 1.5 : 1.0),
          ),
        );
        final focusedBorder = OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.compact ? 8 : 14),
          borderSide: BorderSide(
            color: widget.hasError ? context.errorColor : context.primaryColor,
            width: widget.hasError ? 2.0 : 2.0,
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: textController,
              focusNode: focusNode,
              style: TextStyle(
                fontSize: widget.compact ? 13 : 15,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                labelText: widget.label,
                labelStyle: TextStyle(
                  fontSize: widget.compact ? 12 : 13,
                  color: context.textSecondaryColor,
                ),
                filled: true,
                fillColor: widget.hasError
                    ? context.errorColor.withValues(alpha: 0.05)
                    : (_selectedParty != null
                        ? context.successColor.withValues(alpha: 0.04)
                        : context.surfaceColor),
                isDense: widget.compact,
                contentPadding: widget.compact
                    ? const EdgeInsets.symmetric(horizontal: 10, vertical: 10)
                    : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                enabledBorder: border,
                focusedBorder: focusedBorder,
                prefixIcon: widget.compact
                    ? null
                    : Icon(
                        _selectedParty != null
                            ? LucideIcons.userCheck
                            : LucideIcons.user,
                        size: 18,
                        color: _selectedParty != null
                            ? context.successColor
                            : context.textSecondaryColor,
                      ),
                suffixIcon: _buildSuffixIcon(context),
                suffixIconConstraints:
                    const BoxConstraints(minHeight: 0, minWidth: 0),
              ),
              onSubmitted: (val) {
                _save();
                onFieldSubmitted();
              },
            ),
            // Context chip: Returning / New / Balance info
            if (!widget.compact && _controller.text.isNotEmpty)
              _buildContextChip(context),
          ],
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            shadowColor: Colors.black.withValues(alpha: 0.15),
            color: context.surfaceColor,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360, maxHeight: 300),
              decoration: BoxDecoration(
                border: Border.all(color: context.borderColor.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (context, i) =>
                      Divider(height: 1, color: context.borderColor.withValues(alpha: 0.5)),
                  itemBuilder: (BuildContext context, int index) {
                    final CustomerLedger party = options.elementAt(index);
                    final hasBalance = party.balanceDue > 0.5;
                    final lastVisit = _formatLastVisit(party);
                    return InkWell(
                      onTap: () => onSelected(party),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            // Avatar initial
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: context.primaryColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  party.customerName.isNotEmpty
                                      ? party.customerName[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: context.primaryColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Name + phone + last visit
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    party.customerName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (party.customerPhone != null ||
                                      lastVisit.isNotEmpty)
                                    Row(
                                      children: [
                                        if (party.customerPhone != null) ...[
                                          Icon(LucideIcons.phone,
                                              size: 10,
                                              color: context.textSecondaryColor),
                                          const SizedBox(width: 3),
                                          Text(
                                            party.customerPhone!,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: context.textSecondaryColor,
                                            ),
                                          ),
                                        ],
                                        if (party.customerPhone != null &&
                                            lastVisit.isNotEmpty)
                                          Text(' · ',
                                              style: TextStyle(
                                                  color: context.textSecondaryColor,
                                                  fontSize: 11)),
                                        if (lastVisit.isNotEmpty)
                                          Text(
                                            lastVisit,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: context.textSecondaryColor,
                                            ),
                                          ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Balance chip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: hasBalance
                                    ? context.errorColor.withValues(alpha: 0.1)
                                    : context.successColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                hasBalance
                                    ? '${_formatBalance(party.balanceDue)} due'
                                    : 'Paid ✓',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: hasBalance
                                      ? context.errorColor
                                      : context.successColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget? _buildSuffixIcon(BuildContext context) {
    // When a party is explicitly selected (green border state) show a clear (×)
    // button so the user can reset and type a different / new name.
    if (_selectedParty != null) {
      return GestureDetector(
        onTap: () {
          _controller.clear();
          _lastExplicitlySelectedName = null;
          setState(() {
            _selectedParty = null;
            _isNew = false;
          });
          _save();
        },
        child: Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Icon(LucideIcons.x, size: 16,
              color: context.textSecondaryColor.withValues(alpha: 0.7)),
        ),
      );
    }
    if (_isNew && _controller.text.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: context.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
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
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Icon(LucideIcons.chevronsUpDown, size: 16,
          color: context.textSecondaryColor.withValues(alpha: 0.6)),
    );
  }

  Widget _buildContextChip(BuildContext context) {
    if (_selectedParty != null) {
      final balance = _selectedParty!.balanceDue;
      final hasBalance = balance > 0.5;
      return Padding(
        padding: const EdgeInsets.only(top: 6, left: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.rotateCcw,
                      size: 10, color: Color(0xFF4CAF50)),
                  const SizedBox(width: 5),
                  Text(
                    'Returning Customer',
                    style: const TextStyle(
                      color: Color(0xFF4CAF50),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (hasBalance) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: context.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: context.errorColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${_formatBalance(balance)} pending',
                  style: TextStyle(
                    color: context.errorColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (_isNew) {
      return Padding(
        padding: const EdgeInsets.only(top: 6, left: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: context.primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: context.primaryColor.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.sparkles, size: 10, color: context.primaryColor),
              const SizedBox(width: 5),
              Text(
                'New Customer — will be added to Parties',
                style: TextStyle(
                  color: context.primaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
