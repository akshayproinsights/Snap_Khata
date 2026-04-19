import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_theme.dart';

enum InputState { idle, editing, saving, saved, error }

class MobileTextField extends StatefulWidget {
  final String initialValue;
  final String? placeholder;
  final TextInputType keyboardType;
  final String? errorText;
  final InputState state;
  final Function(String) onSave;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;

  const MobileTextField({
    super.key,
    required this.initialValue,
    required this.onSave,
    this.placeholder,
    this.keyboardType = TextInputType.text,
    this.errorText,
    this.state = InputState.idle,
    this.onEdit,
    this.onCancel,
    this.obscureText = false,
    this.textInputAction,
    this.onSubmitted,
    this.suffixIcon,
  });

  @override
  State<MobileTextField> createState() => _MobileTextFieldState();
}

class _MobileTextFieldState extends State<MobileTextField> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        widget.onEdit?.call();
      } else {
        _handleSave();
      }
    });
  }

  @override
  void didUpdateWidget(covariant MobileTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
    }

    // Auto-focus if transitioned to editing state externally
    if (widget.state == InputState.editing &&
        oldWidget.state != InputState.editing) {
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 3), () {
      _handleSave();
    });
  }

  void _handleSave() {
    _debounceTimer?.cancel();
    if (_controller.text != widget.initialValue ||
        widget.state == InputState.editing) {
      widget.onSave(_controller.text);
    }
  }

  Color _getBorderColor() {
    switch (widget.state) {
      case InputState.error:
        return AppTheme.error;
      case InputState.saved:
        return AppTheme.success;
      case InputState.saving:
        return AppTheme.primary;
      case InputState.editing:
        return AppTheme.warning;
      case InputState.idle:
        return AppTheme.border;
    }
  }

  Widget? _getSuffixIcon() {
    switch (widget.state) {
      case InputState.error:
        return const Icon(Icons.error_outline, color: AppTheme.error, size: 20);
      case InputState.saved:
        return const Icon(Icons.check_circle,
            color: AppTheme.success, size: 20);
      case InputState.saving:
        return const Padding(
          padding: EdgeInsets.all(12.0),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case InputState.editing:
        return IconButton(
          icon: const Icon(Icons.save, color: AppTheme.primary, size: 20),
          onPressed: _handleSave,
          tooltip: 'Save',
        );
      case InputState.idle:
        return widget.suffixIcon;
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _getBorderColor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          onChanged: _onChanged,
          onSubmitted: (value) {
            _handleSave();
            widget.onSubmitted?.call(value);
          },
          enabled: widget.state != InputState.saving,
          obscureText: widget.obscureText,
          decoration: InputDecoration(
            hintText: widget.placeholder,
            suffixIcon: _getSuffixIcon(),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                  color: borderColor,
                  width: widget.state != InputState.idle ? 2 : 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor, width: 2),
            ),
            errorText:
                widget.state == InputState.error ? widget.errorText : null,
          ),
        ),
      ],
    );
  }
}
