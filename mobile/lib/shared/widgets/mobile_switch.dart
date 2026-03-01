import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_theme.dart';

class MobileSwitch extends StatefulWidget {
  final String status;
  final Function(String) onChange;
  final bool disabled;

  const MobileSwitch({
    super.key,
    required this.status,
    required this.onChange,
    this.disabled = false,
  });

  @override
  State<MobileSwitch> createState() => _MobileSwitchState();
}

class _MobileSwitchState extends State<MobileSwitch> {
  bool _showSaved = false;
  Timer? _savedTimer;

  void _handleStatusChange(String newStatus) {
    if (widget.disabled || widget.status == newStatus) return;

    widget.onChange(newStatus);

    setState(() => _showSaved = true);

    _savedTimer?.cancel();
    _savedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showSaved = false);
    });
  }

  @override
  void dispose() {
    _savedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPending = widget.status == 'Pending';

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SegmentButton(
                title: 'Pending',
                icon: Icons.hourglass_empty,
                isSelected: isPending,
                selectedColor: AppTheme.warning,
                disabled: widget.disabled,
                onTap: () => _handleStatusChange('Pending'),
              ),
              const SizedBox(width: 4),
              _SegmentButton(
                title: 'Done',
                icon: Icons.check,
                isSelected: !isPending,
                selectedColor: AppTheme.success,
                disabled: widget.disabled,
                onTap: () => _handleStatusChange('Done'),
              ),
            ],
          ),
        ),
        if (_showSaved) ...[
          const SizedBox(width: 12),
          const Text(
            '✓ Saved!',
            style: TextStyle(
              color: AppTheme.success,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final Color selectedColor;
  final bool disabled;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.selectedColor,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? selectedColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: selectedColor.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
