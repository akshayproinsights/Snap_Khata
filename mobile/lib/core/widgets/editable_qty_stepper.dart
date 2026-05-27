import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/shared/widgets/qty_numpad_sheet.dart';

class EditableQtyStepper extends StatefulWidget {
  final num qty;
  final ValueChanged<num> onChanged;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final double btnSize;
  final double boxWidth;
  final double boxHeight;
  final bool showTrashAtOne;
  final bool isDecimal;

  // Item Context for the Numpad Sheet
  final String? itemName;
  final double? rate;
  final String? unit;

  const EditableQtyStepper({
    super.key,
    required this.qty,
    required this.onChanged,
    this.onDecrement,
    this.onIncrement,
    this.btnSize = 44.0,
    this.boxWidth = 64.0,
    this.boxHeight = 44.0,
    this.showTrashAtOne = true,
    this.isDecimal = false,
    this.itemName,
    this.rate,
    this.unit,
  });

  @override
  State<EditableQtyStepper> createState() => _EditableQtyStepperState();
}

class _EditableQtyStepperState extends State<EditableQtyStepper> {
  String _formatQty(num val) {
    if (widget.isDecimal) {
      return val % 1 == 0 ? val.toInt().toString() : val.toString();
    } else {
      return val.toInt().toString();
    }
  }

  void _handleDecrement() {
    HapticFeedback.lightImpact();
    if (widget.onDecrement != null) {
      widget.onDecrement!();
    } else {
      final current = widget.qty;
      num next;
      if (widget.isDecimal) {
        next = current - 1.0;
        if (next <= 0) next = 0.0;
      } else {
        next = current - 1;
        if (next <= 0) next = 0;
      }
      widget.onChanged(next);
    }
  }

  void _handleIncrement() {
    HapticFeedback.lightImpact();
    if (widget.onIncrement != null) {
      widget.onIncrement!();
    } else {
      final current = widget.qty;
      num next;
      if (widget.isDecimal) {
        next = current + 1.0;
      } else {
        next = current + 1;
      }
      widget.onChanged(next);
    }
  }

  Future<void> _showQtyNumpad(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final result = await showModalBottomSheet<num>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QtyNumpadSheet(
        initial: widget.qty,
        itemName: widget.itemName ?? 'Enter Quantity',
        rate: widget.rate ?? 0.0,
        unit: widget.unit ?? 'NOS',
        isDecimal: widget.isDecimal,
      ),
    );
    if (result != null) {
      widget.onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showTrash = widget.showTrashAtOne && widget.qty <= 1;

    return Container(
      decoration: BoxDecoration(
        color: context.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.borderColor,
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Decrement / Remove button
          GestureDetector(
            onTap: _handleDecrement,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: widget.btnSize,
              height: widget.btnSize,
              decoration: BoxDecoration(
                color: showTrash
                    ? context.errorColor.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(13),
                  bottomLeft: Radius.circular(13),
                ),
              ),
              child: Icon(
                showTrash ? LucideIcons.trash2 : LucideIcons.minus,
                size: 16,
                color: showTrash ? context.errorColor : context.primaryColor,
              ),
            ),
          ),

          // Central Tappable Quantity Box
          GestureDetector(
            onTap: () => _showQtyNumpad(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: widget.boxWidth,
              height: widget.boxHeight,
              decoration: BoxDecoration(
                color: context.surfaceColor,
                border: Border(
                  left: BorderSide(color: context.borderColor),
                  right: BorderSide(color: context.borderColor),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _formatQty(widget.qty),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: context.primaryColor, // Draw visual interest as interactive element
                ),
              ),
            ),
          ),

          // Increment button
          GestureDetector(
            onTap: _handleIncrement,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: widget.btnSize,
              height: widget.btnSize,
              decoration: BoxDecoration(
                color: context.primaryColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(13),
                  bottomRight: Radius.circular(13),
                ),
              ),
              child: Icon(
                LucideIcons.plus,
                size: 16,
                color: context.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
