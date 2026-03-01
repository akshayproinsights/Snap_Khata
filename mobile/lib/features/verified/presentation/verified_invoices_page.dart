import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/verified/data/verified_repository.dart';
import 'package:mobile/features/verified/domain/models/verified_models.dart';
import 'package:mobile/features/verified/presentation/providers/verified_provider.dart';
import 'package:mobile/core/utils/whatsapp_helper.dart';
import 'package:mobile/shared/widgets/app_toast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// ─── Group-by options ────────────────────────────────────────────────────────

enum GroupByField { receipt, date, customer, vehicle }

extension GroupByFieldExt on GroupByField {
  String get label {
    switch (this) {
      case GroupByField.receipt:
        return 'Receipt #';
      case GroupByField.date:
        return 'Date';
      case GroupByField.customer:
        return 'Customer';
      case GroupByField.vehicle:
        return 'Vehicle';
    }
  }

  IconData get icon {
    switch (this) {
      case GroupByField.receipt:
        return LucideIcons.fileText;
      case GroupByField.date:
        return LucideIcons.calendar;
      case GroupByField.customer:
        return LucideIcons.user;
      case GroupByField.vehicle:
        return LucideIcons.truck;
    }
  }

  String keyFor(VerifiedInvoice inv) {
    switch (this) {
      case GroupByField.receipt:
        return inv.receiptNumber.isEmpty ? '—' : inv.receiptNumber;
      case GroupByField.date:
        return inv.date.isEmpty ? '—' : inv.date;
      case GroupByField.customer:
        return inv.customerName.isEmpty ? '—' : inv.customerName;
      case GroupByField.vehicle:
        return inv.vehicleNumber.isEmpty ? '—' : inv.vehicleNumber;
    }
  }
}

// ─── Page ────────────────────────────────────────────────────────────────────

class VerifiedInvoicesPage extends ConsumerStatefulWidget {
  const VerifiedInvoicesPage({super.key});

  @override
  ConsumerState<VerifiedInvoicesPage> createState() =>
      _VerifiedInvoicesPageState();
}

class _VerifiedInvoicesPageState extends ConsumerState<VerifiedInvoicesPage> {
  final Set<String> _selectedIds = {};
  bool _showFilters = false;
  bool _isExporting = false;

  // Filters
  String _searchQuery = '';
  String _receiptNumber = '';
  String _vehicleNumber = '';
  String _customerName = '';
  String _description = '';

  // Grouping
  GroupByField _groupBy = GroupByField.receipt;
  final Set<String> _expandedGroups = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(verifiedProvider.notifier).fetchRecords());
  }

  Future<void> _exportVerifiedInvoices() async {
    setState(() => _isExporting = true);
    try {
      final repo = VerifiedRepository();
      final filters = <String, dynamic>{};
      if (_searchQuery.isNotEmpty) filters['search'] = _searchQuery;
      if (_receiptNumber.isNotEmpty) filters['receipt_number'] = _receiptNumber;
      if (_vehicleNumber.isNotEmpty) filters['vehicle_number'] = _vehicleNumber;
      if (_customerName.isNotEmpty) filters['customer_name'] = _customerName;

      final bytes = await repo.exportToExcel(filters);
      final dir = await getTemporaryDirectory();
      final timestamp =
          DateTime.now().toIso8601String().replaceAll(RegExp(r'[:\.]'), '-');
      final filePath = '${dir.path}/verified_invoices_$timestamp.xlsx';
      await File(filePath).writeAsBytes(bytes as List<int>);

      await Share.shareXFiles(
        [
          XFile(filePath,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        ],
        subject: 'DigiEntry Verified Invoices Export',
        text: 'Verified invoices exported from DigiEntry',
      );
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Export failed: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _applyFilters() {
    _expandedGroups.clear();
    ref.read(verifiedProvider.notifier).fetchRecords(
          search: _searchQuery,
          receiptNumber: _receiptNumber,
          vehicleNumber: _vehicleNumber,
          customerName: _customerName,
          description: _description,
        );
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _receiptNumber = '';
      _vehicleNumber = '';
      _customerName = '';
      _description = '';
      _showFilters = false;
      _expandedGroups.clear();
    });
    _applyFilters();
  }

  void _handleToggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _handleSelectAll(List<VerifiedInvoice> items) {
    setState(() {
      if (_selectedIds.length == items.length && items.isNotEmpty) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(items.map((i) => i.rowId));
      }
    });
  }

  void _handleBulkDelete() async {
    if (_selectedIds.isEmpty) return;

    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Delete Selected?',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: Text(
                  'Are you sure you want to delete ${_selectedIds.length} verified records? This action cannot be undone.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete'),
                ),
              ],
            ));

    if (confirm == true) {
      ref.read(verifiedProvider.notifier).deleteBulk(_selectedIds.toList());
      setState(() => _selectedIds.clear());
    }
  }

  // Build ordered map: groupKey → list of invoices
  Map<String, List<VerifiedInvoice>> _buildGroups(
      List<VerifiedInvoice> records) {
    final map = <String, List<VerifiedInvoice>>{};
    for (final inv in records) {
      final key = _groupBy.keyFor(inv);
      map.putIfAbsent(key, () => []).add(inv);
    }
    // Sort keys alphabetically/numerically
    final sortedMap = <String, List<VerifiedInvoice>>{};
    final keys = map.keys.toList()..sort();
    for (final key in keys) {
      sortedMap[key] = map[key]!;
    }
    return sortedMap;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(verifiedProvider);
    final groups = _buildGroups(state.records);
    final isAllSelected =
        _selectedIds.length == state.records.length && state.records.isNotEmpty;

    final double totalAmount =
        state.records.fold(0, (sum, item) => sum + item.amount);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: () async {
          _clearFilters();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ─── Modern Sliver App Bar ──────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 180.0,
              pinned: true,
              backgroundColor: AppTheme.primary,
              iconTheme: const IconThemeData(color: Colors.white),
              actions: [
                IconButton(
                  icon: Icon(
                      _showFilters ? LucideIcons.filterX : LucideIcons.filter,
                      color: Colors.white),
                  onPressed: () => setState(() => _showFilters = !_showFilters),
                ),
                _isExporting
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white)),
                      )
                    : IconButton(
                        icon: const Icon(LucideIcons.download,
                            color: Colors.white),
                        tooltip: 'Export to Excel',
                        onPressed: _exportVerifiedInvoices,
                      ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                title: const Text('Verified Invoices',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20)),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primary,
                        AppTheme.primary.withBlue(200)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Decorative circles
                      Positioned(
                          right: -50,
                          top: -50,
                          child: CircleAvatar(
                              radius: 100,
                              backgroundColor: Colors.white.withOpacity(0.05))),
                      Positioned(
                          right: 100,
                          bottom: -20,
                          child: CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.white.withOpacity(0.1))),

                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                          child: Row(
                            children: [
                              // Total Invoices
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('TOTAL INVOICES',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2)),
                                    const SizedBox(height: 4),
                                    Text('${state.records.length}',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              // Total Amount
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('TOTAL AMOUNT',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2)),
                                    const SizedBox(height: 4),
                                    Text('₹${totalAmount.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ─── Filters & Top Controls ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // Filter Panel Container with smooth size change
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _showFilters
                        ? _buildFiltersPanel()
                        : const SizedBox.shrink(),
                  ),

                  // Group by Chips - sleek look
                  _buildGroupByChips(),

                  // Bulk Actions Row
                  _buildBulkActionsRow(
                      isAllSelected, state.records, groups.length),

                  // Error State Display
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: AppTheme.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppTheme.error.withOpacity(0.3))),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.alertCircle,
                                color: AppTheme.error),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(
                                    'Error loading invoices: ${state.error}',
                                    style: const TextStyle(
                                        color: AppTheme.error))),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ─── Empty / Loading / List ─────────────────────────────────────────
            if (state.isLoading && state.records.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.records.isEmpty && state.error == null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.fileSearch,
                            size: 64, color: AppTheme.primary),
                      ),
                      const SizedBox(height: 24),
                      const Text('No Invoices Found',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 8),
                      const Text('Adjust your filters or sync new invoices.',
                          style: TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 24),
                      if (state.records.isEmpty &&
                          (_searchQuery.isNotEmpty ||
                              _receiptNumber.isNotEmpty ||
                              _customerName.isNotEmpty))
                        OutlinedButton.icon(
                          onPressed: _clearFilters,
                          icon: const Icon(LucideIcons.xCircle),
                          label: const Text('Clear Filters'),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primary),
                        )
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final keys = groups.keys.toList();
                      final key = keys[index];
                      final bills = groups[key]!;
                      final isExpanded = _expandedGroups.contains(key);
                      return _buildGroupSection(key, bills, isExpanded);
                    },
                    childCount: groups.keys.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Filter panel ────────────────────────────────────────────────────────────

  Widget _buildFiltersPanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Advanced Filters',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              TextButton(
                  onPressed: _clearFilters,
                  style: TextButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0)),
                  child: const Text('Clear All')),
            ],
          ),
          const SizedBox(height: 16),
          _buildSearchField(
              hint: 'Search anything (ex: description)',
              icon: LucideIcons.search,
              initialValue: _searchQuery,
              onChanged: (v) {
                _searchQuery = v;
                _applyFilters();
              }),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _buildSearchField(
                      hint: 'Receipt #',
                      icon: LucideIcons.hash,
                      initialValue: _receiptNumber,
                      onChanged: (v) {
                        _receiptNumber = v;
                        _applyFilters();
                      })),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildSearchField(
                      hint: 'Vehicle #',
                      icon: LucideIcons.car,
                      initialValue: _vehicleNumber,
                      onChanged: (v) {
                        _vehicleNumber = v;
                        _applyFilters();
                      })),
            ],
          ),
          const SizedBox(height: 12),
          _buildSearchField(
              hint: 'Customer Name',
              icon: LucideIcons.user,
              initialValue: _customerName,
              onChanged: (v) {
                _customerName = v;
                _applyFilters();
              }),
        ],
      ),
    );
  }

  Widget _buildSearchField(
      {required String hint,
      required IconData icon,
      required String initialValue,
      required Function(String) onChanged}) {
    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade500),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
      ),
      onChanged: onChanged,
    );
  }

  // ─── Group-by chips ─────────────────────────────────────────────────────────

  Widget _buildGroupByChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('GROUP VIEW BY',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 1.2)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: GroupByField.values
                  .map((field) => _buildChip(field))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(GroupByField field) {
    final isSelected = _groupBy == field;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _groupBy = field;
            _expandedGroups.clear();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.fastOutSlowIn,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : Colors.white,
            border: Border.all(
                color: isSelected ? AppTheme.primary : Colors.grey.shade300,
                width: 1.5),
            borderRadius: BorderRadius.circular(30),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: AppTheme.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(field.icon,
                  size: 14,
                  color: isSelected ? Colors.white : Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(field.label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.grey.shade700)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Bulk Select Bar ────────────────────────────────────────────────────────

  Widget _buildBulkActionsRow(
      bool isAllSelected, List<VerifiedInvoice> items, int groupCount) {
    return Column(
      children: [
        if (_selectedIds.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withOpacity(0.2))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                          color: AppTheme.primary, shape: BoxShape.circle),
                      child: Text('${_selectedIds.length}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    const Text('Selected',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary)),
                  ],
                ),
                TextButton.icon(
                    style: TextButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        padding: const EdgeInsets.symmetric(horizontal: 16)),
                    onPressed: _handleBulkDelete,
                    icon: const Icon(LucideIcons.trash2, size: 18),
                    label: const Text('Delete Selected',
                        style: TextStyle(fontWeight: FontWeight.bold)))
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              Transform.scale(
                scale: 0.9,
                child: Checkbox(
                    value: isAllSelected,
                    activeColor: AppTheme.primary,
                    onChanged: (_) => _handleSelectAll(items)),
              ),
              const Text('Select All',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20)),
                child: Text('${items.length} bills · $groupCount groups',
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Grouped list section ────────────────────────────────────────────────────

  Widget _buildGroupSection(
      String groupKey, List<VerifiedInvoice> bills, bool isExpanded) {
    final totalAmount = bills.fold<double>(0, (sum, b) => sum + b.amount);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // ── Group header ───────────────────────────────────────────────
            InkWell(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedGroups.remove(groupKey);
                  } else {
                    _expandedGroups.add(groupKey);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isExpanded
                      ? AppTheme.primary.withOpacity(0.03)
                      : Colors.white,
                  border: Border(
                      bottom: BorderSide(
                          color: isExpanded
                              ? Colors.grey.shade200
                              : Colors.transparent)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(_groupBy.icon,
                          size: 20, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(groupKey,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppTheme.textPrimary)),
                          const SizedBox(height: 4),
                          Text(
                              '${bills.length} item${bills.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹${totalAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppTheme.primary)),
                        const SizedBox(height: 4),
                        AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 250),
                          child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  shape: BoxShape.circle),
                              child: const Icon(LucideIcons.chevronDown,
                                  size: 16, color: AppTheme.textSecondary)),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),

            // ── Bills inside group ─────────────────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.fastOutSlowIn,
              child: ConstrainedBox(
                constraints: isExpanded
                    ? const BoxConstraints()
                    : const BoxConstraints(maxHeight: 0),
                child: Column(
                  children: bills.asMap().entries.map((entry) {
                    final i = entry.key;
                    final bill = entry.value;
                    return Column(
                      children: [
                        _buildBillRow(bill),
                        if (i < bills.length - 1)
                          Divider(
                              height: 1,
                              indent: 64,
                              color: Colors.grey.shade100),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Individual bill row inside an expanded group ─────────────────────────

  Widget _buildBillRow(VerifiedInvoice record) {
    final isSelected = _selectedIds.contains(record.rowId);

    Color typeColor = Colors.grey.shade700;
    Color typeBg = Colors.grey.shade100;
    IconData? typeIcon = LucideIcons.fileText;

    if (record.type.toUpperCase().contains('PART')) {
      typeColor = Colors.blue.shade700;
      typeBg = Colors.blue.shade50;
      typeIcon = LucideIcons.package;
    } else if (record.type.toUpperCase().contains('LABOUR') ||
        record.type.toUpperCase().contains('SERVICE')) {
      typeColor = Colors.orange.shade800;
      typeBg = Colors.orange.shade50;
      typeIcon = LucideIcons.wrench;
    }

    return InkWell(
      onTap: () => _handleToggleSelect(record.rowId),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        color: isSelected
            ? AppTheme.primary.withOpacity(0.04)
            : Colors.transparent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 12),
              child: Transform.scale(
                scale: 0.9,
                child: Checkbox(
                    value: isSelected,
                    activeColor: AppTheme.primary,
                    onChanged: (v) => _handleToggleSelect(record.rowId)),
              ),
            ),

            // Bill details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: description + type badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          record.description.isEmpty ? '—' : record.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              height: 1.3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: typeBg,
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: typeColor.withOpacity(0.2))),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(typeIcon, size: 10, color: typeColor),
                            const SizedBox(width: 4),
                            Text(record.type,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: typeColor)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Metadata properties - rich visuals
                  Wrap(spacing: 12, runSpacing: 8, children: [
                    if (_groupBy != GroupByField.vehicle &&
                        record.vehicleNumber.isNotEmpty)
                      _buildMetaTag(LucideIcons.car, record.vehicleNumber),
                    if (_groupBy != GroupByField.customer &&
                        record.customerName.isNotEmpty)
                      _buildMetaTag(LucideIcons.user, record.customerName),
                    if (_groupBy != GroupByField.date && record.date.isNotEmpty)
                      _buildMetaTag(LucideIcons.calendar, record.date),
                    if (_groupBy != GroupByField.receipt &&
                        record.receiptNumber.isNotEmpty)
                      _buildMetaTag(LucideIcons.hash, record.receiptNumber),
                  ]),

                  const SizedBox(height: 14),

                  // Qty / Rate / Amount Row
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade100)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            _miniStat('Qty', record.quantity.toString()),
                            const SizedBox(width: 16),
                            _miniStat(
                                'Rate', '₹${record.rate.toStringAsFixed(0)}'),
                          ],
                        ),
                        Row(
                          children: [
                            _miniStat(
                                'Total', '₹${record.amount.toStringAsFixed(0)}',
                                highlight: true),
                            const SizedBox(width: 16),
                            Container(
                                width: 1,
                                height: 24,
                                color: Colors.grey.shade300),
                            const SizedBox(width: 16),
                            // Share button / Link
                            GestureDetector(
                              onTap: () {
                                final msg = 'Invoice Verified:\n'
                                    'Receipt #: ${record.receiptNumber}\n'
                                    'Customer: ${record.customerName}\n'
                                    'Vehicle: ${record.vehicleNumber}\n'
                                    'Description: ${record.description}\n'
                                    'Amount: ₹${record.amount}\n'
                                    'Link: ${record.receiptLink}';
                                WhatsAppHelper.launchWhatsApp(context, msg);
                              },
                              child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                      color: AppTheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(LucideIcons.share2,
                                      size: 16, color: AppTheme.primary)),
                            ),
                            if (record.receiptLink.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  // A user normally could view the link here.
                                },
                                child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(LucideIcons.externalLink,
                                        size: 16,
                                        color: AppTheme.textSecondary)),
                              ),
                            ]
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaTag(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _miniStat(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: crossAxisAlignmentFromName(label),
      children: [
        Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: 9,
                color: highlight ? AppTheme.primary : Colors.grey.shade500,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: highlight ? 15 : 13,
                fontWeight: FontWeight.bold,
                color: highlight ? AppTheme.primary : AppTheme.textPrimary)),
      ],
    );
  }

  CrossAxisAlignment crossAxisAlignmentFromName(String name) {
    if (name.toLowerCase() == 'qty') return CrossAxisAlignment.start;
    if (name.toLowerCase() == 'total') return CrossAxisAlignment.end;
    return CrossAxisAlignment.center;
  }
}
