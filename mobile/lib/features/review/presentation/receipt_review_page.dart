import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/review/domain/models/review_models.dart';
import 'package:mobile/features/review/presentation/providers/review_provider.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/utils/whatsapp_utils.dart';

class ReceiptReviewPage extends ConsumerStatefulWidget {
  final InvoiceReviewGroup group;

  const ReceiptReviewPage({super.key, required this.group});

  @override
  ConsumerState<ReceiptReviewPage> createState() => _ReceiptReviewPageState();
}

class _ReceiptReviewPageState extends ConsumerState<ReceiptReviewPage> {
  void _showFullImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Receipt Image'),
          ),
          body: InteractiveViewer(
            child: Center(
              child: Hero(
                tag: 'receipt_image_${widget.group.receiptNumber}',
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(color: Colors.white)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _markAllDone() {
    final group = widget.group;
    final header = group.header;
    if (header != null && header.verificationStatus != 'Done') {
      final newRecord = ReviewRecord(
          rowId: header.rowId,
          receiptNumber: header.receiptNumber,
          date: header.date,
          description: header.description,
          amount: header.amount,
          verificationStatus: 'Done',
          receiptLink: header.receiptLink,
          dateBbox: header.dateBbox,
          receiptNumberBbox: header.receiptNumberBbox,
          combinedBbox: header.combinedBbox,
          lineItemBbox: header.lineItemBbox,
          isHeader: header.isHeader);
      ref.read(reviewProvider.notifier).updateDateRecord(newRecord);
    }

    for (var item in group.lineItems) {
      if (item.verificationStatus != 'Done') {
        final newRecord = ReviewRecord(
            rowId: item.rowId,
            receiptNumber: item.receiptNumber,
            date: item.date,
            description: item.description,
            amount: item.amount,
            verificationStatus: 'Done',
            receiptLink: item.receiptLink,
            dateBbox: item.dateBbox,
            receiptNumberBbox: item.receiptNumberBbox,
            combinedBbox: item.combinedBbox,
            lineItemBbox: item.lineItemBbox,
            isHeader: item.isHeader);
        ref.read(reviewProvider.notifier).updateAmountRecord(newRecord);
      }
    }

    // Automatically go back after marking done
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    // Read fresh group from state to reflect updates immediately
    final state = ref.watch(reviewProvider);
    final group = state.groups.firstWhere(
        (g) => g.receiptNumber == widget.group.receiptNumber,
        orElse: () => widget.group);

    final header = group.header;

    // Line Item Hoisting: Red items (hasError) at the top!
    final sortedLineItems = List<ReviewRecord>.from(group.lineItems);
    sortedLineItems.sort((a, b) {
      if (a.hasError && !b.hasError) return -1;
      if (!a.hasError && b.hasError) return 1;
      return 0; // Keep original order otherwise
    });

    final hasAnyError = group.hasError;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Receipt #${group.receiptNumber}'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.share2),
            onPressed: () async {
              // Calculate total amount from line items if available, else from header amount
              final double totalAmount = group.header?.amount ??
                  group.lineItems
                      .fold<double>(0.0, (sum, item) => sum + item.amount);

              final shareUrl =
                  'https://mydigientry.com/receipt/${group.receiptNumber}';

              final caption = WhatsAppUtils.getWhatsAppCaption(
                status: OrderPaymentStatus
                    .fullyPaid, // Default to paid/ready for review
                customerName: header?.customerName ??
                    'Customer', // Use backend customer name if available
                businessName:
                    'Business', // Default to generic, but should really be pulled from user session/store
                orderNumber: group.receiptNumber,
                totalAmount: totalAmount,
              );
              final message = '$caption\n\n📋 View full order:\n$shareUrl';

              // Open custom input dialog for phone number (pre-filled if available from DB)
              final phoneController =
                  TextEditingController(text: header?.mobileNumber ?? '');
              final result = await showDialog<String>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Share Receipt'),
                  content: TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Customer Phone Number',
                      prefixText: '+91 ',
                      hintText: 'e.g. 9876543210',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => context.pop(phoneController.text),
                      child: const Text('Share to WhatsApp'),
                    ),
                  ],
                ),
              );

              if (result != null && result.isNotEmpty && context.mounted) {
                final opened = await WhatsAppUtils.openWhatsAppChat(
                  phone: result,
                  message: message,
                );

                if (!opened && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Could not open WhatsApp. Please ensure it is installed.')),
                  );
                }
              }
            },
            tooltip: 'Share via WhatsApp',
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Image Viewer
          if (header != null && header.receiptLink.isNotEmpty)
            GestureDetector(
              onTap: () => _showFullImage(header.receiptLink),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.25,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.black,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'receipt_image_${group.receiptNumber}',
                      child: CachedNetworkImage(
                        imageUrl: header.receiptLink,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        placeholder: (context, url) => const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white)),
                        errorWidget: (context, url, error) => const Icon(
                            LucideIcons.imageOff,
                            color: Colors.white54,
                            size: 40),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.maximize,
                                color: Colors.white, size: 14),
                            SizedBox(width: 6),
                            Text('Tap to expand',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom Scrollable Fields
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (header != null) _buildHeaderCard(header),
                const SizedBox(height: 16),
                const Text('Line Items',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                if (sortedLineItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                        child: Text('No line items found.',
                            style: TextStyle(color: AppTheme.textSecondary))),
                  ),
                ...sortedLineItems.map((item) => _buildLineItemCard(item)),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: double.infinity,
          child: FloatingActionButton.extended(
            onPressed: hasAnyError ? null : _markAllDone,
            backgroundColor: hasAnyError ? Colors.grey.shade400 : Colors.green,
            foregroundColor: Colors.white,
            elevation: hasAnyError ? 0 : 4,
            icon:
                Icon(hasAnyError ? LucideIcons.alertCircle : LucideIcons.check),
            label: Text(
              hasAnyError ? 'Fix Errors to Continue' : 'Mark as Done',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(ReviewRecord header) {
    final isError = header.hasError;
    final isDone = header.verificationStatus == 'Done';

    Color borderColor = AppTheme.border;
    Color bgColor = Colors.white;
    if (isError) {
      borderColor = Colors.red.shade400;
      bgColor = Colors.red.shade50;
    } else if (isDone) {
      borderColor = Colors.green.shade400;
      bgColor = Colors.green.shade50;
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: borderColor, width: isError || isDone ? 2 : 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.fileText,
                  size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              const Text('Header Details',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppTheme.textSecondary)),
              const Spacer(),
              if (isError)
                const Icon(LucideIcons.alertCircle,
                    color: Colors.red, size: 16),
              if (!isError && isDone)
                const Icon(LucideIcons.checkCircle,
                    color: Colors.green, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: header.receiptNumber,
                  decoration: _inputDecoration('Receipt No.').copyWith(
                    errorText:
                        header.receiptNumber.trim().isEmpty ? 'Required' : null,
                    enabledBorder: header.hasReceiptDoubt
                        ? OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: Colors.red.shade400, width: 1.5),
                          )
                        : null,
                    focusedBorder: header.hasReceiptDoubt
                        ? OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: Colors.red.shade400, width: 2),
                          )
                        : null,
                    fillColor: header.hasReceiptDoubt
                        ? Colors.red.shade50
                        : Colors.white,
                  ),
                  onFieldSubmitted: (val) {
                    if (val != header.receiptNumber) {
                      final newRecord = ReviewRecord(
                          rowId: header.rowId,
                          receiptNumber: val,
                          date: header.date,
                          description: header.description,
                          amount: header.amount,
                          verificationStatus: header.verificationStatus,
                          receiptLink: header.receiptLink,
                          dateBbox: header.dateBbox,
                          receiptNumberBbox: header.receiptNumberBbox,
                          combinedBbox: header.combinedBbox,
                          lineItemBbox: header.lineItemBbox,
                          isHeader: header.isHeader,
                          auditFindings: header.auditFindings);
                      ref
                          .read(reviewProvider.notifier)
                          .updateDateRecord(newRecord);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    DateTime? initialDate;
                    try {
                      if (header.date.isNotEmpty) {
                        try {
                          initialDate =
                              DateFormat('dd-MM-yyyy').parseStrict(header.date);
                        } catch (e) {
                          initialDate = DateTime.parse(header.date);
                        }
                      }
                    } catch (_) {}

                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initialDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );

                    if (picked != null) {
                      final formattedDate =
                          DateFormat('dd-MM-yyyy').format(picked);
                      if (formattedDate != header.date) {
                        final newRecord = ReviewRecord(
                            rowId: header.rowId,
                            receiptNumber: header.receiptNumber,
                            date: formattedDate,
                            description: header.description,
                            amount: header.amount,
                            verificationStatus: header.verificationStatus,
                            receiptLink: header.receiptLink,
                            dateBbox: header.dateBbox,
                            receiptNumberBbox: header.receiptNumberBbox,
                            combinedBbox: header.combinedBbox,
                            lineItemBbox: header.lineItemBbox,
                            isHeader: header.isHeader,
                            auditFindings: header.auditFindings);
                        ref
                            .read(reviewProvider.notifier)
                            .updateDateRecord(newRecord);
                      }
                    }
                  },
                  child: IgnorePointer(
                    child: TextFormField(
                      key: ValueKey('date_${header.date}'),
                      initialValue: header.date,
                      readOnly: true,
                      decoration: _inputDecoration('Date').copyWith(
                        errorText:
                            header.date.trim().isEmpty ? 'Required' : null,
                        suffixIcon: const Icon(LucideIcons.calendar, size: 16),
                        enabledBorder: header.hasDateDoubt
                            ? OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: Colors.red.shade400, width: 1.5),
                              )
                            : null,
                        focusedBorder: header.hasDateDoubt
                            ? OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: Colors.red.shade400, width: 2),
                              )
                            : null,
                        fillColor: header.hasDateDoubt
                            ? Colors.red.shade50
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (header.verificationStatus == 'Duplicate Receipt Number')
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text('Error: Duplicate Receipt Number. Please fix it.',
                  style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            )
        ],
      ),
    );
  }

  Widget _buildLineItemCard(ReviewRecord item) {
    final isError = item.hasError;
    final isDone = item.verificationStatus == 'Done';

    Color borderColor = AppTheme.border;
    Color bgColor = Colors.white;
    if (isError) {
      borderColor = Colors.red.shade400;
      bgColor = Colors.red.shade50;
    } else if (isDone) {
      borderColor = Colors.green.shade400;
      bgColor = Colors.green.shade50;
    }

    // Checking if amount mismatch exists
    final hasMismatch =
        item.amountMismatch != null && item.amountMismatch!.abs() > 0.01;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isError ? 2 : 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: item.description,
                  decoration: _inputDecoration('Description').copyWith(
                    errorText:
                        item.description.trim().isEmpty ? 'Required' : null,
                  ),
                  maxLines: null,
                  onFieldSubmitted: (val) {
                    if (val != item.description) {
                      final newRecord = ReviewRecord(
                          rowId: item.rowId,
                          receiptNumber: item.receiptNumber,
                          date: item.date,
                          description: val,
                          amount: item.amount,
                          verificationStatus: item.verificationStatus,
                          receiptLink: item.receiptLink,
                          dateBbox: item.dateBbox,
                          receiptNumberBbox: item.receiptNumberBbox,
                          combinedBbox: item.combinedBbox,
                          lineItemBbox: item.lineItemBbox,
                          isHeader: item.isHeader,
                          quantity: item.quantity,
                          rate: item.rate,
                          amountMismatch: item.amountMismatch);
                      ref
                          .read(reviewProvider.notifier)
                          .updateAmountRecord(newRecord);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: item.amount.toStringAsFixed(2),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: AppTheme.primary),
                  decoration: _inputDecoration('Total (₹)'),
                  onFieldSubmitted: (val) {
                    final newAmount = double.tryParse(val);
                    if (newAmount != null && newAmount != item.amount) {
                      // Recalculate mismatch if quantity and rate exist. Assuming we trust the user overriding the total.
                      // Alternatively just clear amountMismatch.
                      final newRecord = ReviewRecord(
                          rowId: item.rowId,
                          receiptNumber: item.receiptNumber,
                          date: item.date,
                          description: item.description,
                          amount: newAmount,
                          verificationStatus: item.verificationStatus,
                          receiptLink: item.receiptLink,
                          dateBbox: item.dateBbox,
                          receiptNumberBbox: item.receiptNumberBbox,
                          combinedBbox: item.combinedBbox,
                          lineItemBbox: item.lineItemBbox,
                          isHeader: item.isHeader,
                          quantity: item.quantity,
                          rate: item.rate,
                          amountMismatch: 0);
                      ref
                          .read(reviewProvider.notifier)
                          .updateAmountRecord(newRecord);
                    }
                  },
                ),
              ),
            ],
          ),
          if (item.quantity != null && item.rate != null && item.rate! > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: TextFormField(
                  initialValue: item.quantity?.toStringAsFixed(2),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDecoration('Qty'),
                  onFieldSubmitted: (val) {
                    final newQty = double.tryParse(val);
                    if (newQty != null) {
                      // recalculate mismatch
                      final newMismatch = (newQty * item.rate!) - item.amount;
                      final newRecord = ReviewRecord(
                          rowId: item.rowId,
                          receiptNumber: item.receiptNumber,
                          date: item.date,
                          description: item.description,
                          amount: item.amount,
                          verificationStatus: item.verificationStatus,
                          receiptLink: item.receiptLink,
                          dateBbox: item.dateBbox,
                          receiptNumberBbox: item.receiptNumberBbox,
                          combinedBbox: item.combinedBbox,
                          lineItemBbox: item.lineItemBbox,
                          isHeader: item.isHeader,
                          quantity: newQty,
                          rate: item.rate,
                          amountMismatch: newMismatch);
                      ref
                          .read(reviewProvider.notifier)
                          .updateAmountRecord(newRecord);
                    }
                  },
                )),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text('×',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ),
                Expanded(
                    child: TextFormField(
                  initialValue: item.rate?.toStringAsFixed(2),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDecoration('Rate (₹)'),
                  onFieldSubmitted: (val) {
                    final newRate = double.tryParse(val);
                    if (newRate != null && item.quantity != null) {
                      final newMismatch =
                          (item.quantity! * newRate) - item.amount;
                      final newRecord = ReviewRecord(
                          rowId: item.rowId,
                          receiptNumber: item.receiptNumber,
                          date: item.date,
                          description: item.description,
                          amount: item.amount,
                          verificationStatus: item.verificationStatus,
                          receiptLink: item.receiptLink,
                          dateBbox: item.dateBbox,
                          receiptNumberBbox: item.receiptNumberBbox,
                          combinedBbox: item.combinedBbox,
                          lineItemBbox: item.lineItemBbox,
                          isHeader: item.isHeader,
                          quantity: item.quantity,
                          rate: newRate,
                          amountMismatch: newMismatch);
                      ref
                          .read(reviewProvider.notifier)
                          .updateAmountRecord(newRecord);
                    }
                  },
                )),
                const Spacer(),
              ],
            ),
          ],
          if (isError) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(LucideIcons.alertTriangle,
                    size: 14, color: Colors.red),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                      hasMismatch
                          ? 'Math Error: Qty × Rate ≠ Total'
                          : 'Missing required fields',
                      style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }
}
