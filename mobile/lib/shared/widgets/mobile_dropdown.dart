import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_theme.dart';

class MobileDropdown extends StatefulWidget {
  final String value;
  final String placeholder;
  final String label;
  final Future<List<String>> Function(String) getSuggestions;
  final Function(String) onChange;
  final int debounceMs;
  final int minChars;

  const MobileDropdown({
    super.key,
    required this.value,
    required this.onChange,
    required this.placeholder,
    required this.label,
    required this.getSuggestions,
    this.debounceMs = 300,
    this.minChars = 2,
  });

  @override
  State<MobileDropdown> createState() => _MobileDropdownState();
}

class _MobileDropdownState extends State<MobileDropdown> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  List<String> _suggestions = [];
  bool _isLoading = false;
  Timer? _debounceTimer;

  // GlobalKey to calculate overlay position
  final GlobalKey _textFieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _hideDropdown();
      } else if (_controller.text.length >= widget.minChars &&
          _suggestions.isNotEmpty) {
        _showDropdown();
      }
    });
  }

  @override
  void didUpdateWidget(covariant MobileDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _hideDropdown();
    _debounceTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    widget.onChange(query);
    _debounceTimer?.cancel();

    if (query.length < widget.minChars) {
      setState(() {
        _suggestions = [];
      });
      _hideDropdown();
      return;
    }

    _debounceTimer = Timer(Duration(milliseconds: widget.debounceMs), () async {
      setState(() => _isLoading = true);
      try {
        final results = await widget.getSuggestions(query);
        if (mounted) {
          setState(() {
            _suggestions = results;
          });
          if (_focusNode.hasFocus && results.isNotEmpty) {
            _showDropdown();
          } else {
            _hideDropdown();
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _suggestions = []);
          _hideDropdown();
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  void _handleSelect(String suggestion) {
    _controller.text = suggestion;
    widget.onChange(suggestion);
    _hideDropdown();
    _focusNode.unfocus();
  }

  void _handleClear() {
    _controller.clear();
    widget.onChange('');
    setState(() => _suggestions = []);
    _hideDropdown();
    _focusNode.requestFocus();
  }

  void _toggleDropdown() async {
    if (_overlayEntry != null) {
      _hideDropdown();
    } else {
      _focusNode.requestFocus();
      setState(() => _isLoading = true);
      try {
        final results = await widget.getSuggestions(_controller.text);
        if (mounted) {
          setState(() => _suggestions = results);
          if (results.isNotEmpty) _showDropdown();
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showDropdown() {
    if (_overlayEntry != null) return;

    final RenderBox renderBox =
        _textFieldKey.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Dismissible background layer
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _hideDropdown();
                _focusNode.unfocus();
              },
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: offset.dx,
            top: offset.dy + size.height + 4,
            width: size.width,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              color: AppTheme.surface,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, color: AppTheme.border),
                  itemBuilder: (context, index) {
                    final suggestion = _suggestions[index];
                    return InkWell(
                      onTap: () => _handleSelect(suggestion),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Text(
                          suggestion,
                          style: const TextStyle(
                              fontSize: 16, color: AppTheme.textPrimary),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label.isNotEmpty) ...[
          Text(
            widget.label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextField(
          key: _textFieldKey,
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: widget.placeholder,
            prefixIcon: const Icon(Icons.search,
                color: AppTheme.textSecondary, size: 20),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.primary),
                    ),
                  ),
                if (_controller.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 18, color: AppTheme.textSecondary),
                    onPressed: _handleClear,
                    splashRadius: 20,
                  ),
                IconButton(
                  icon: Icon(
                    _overlayEntry != null
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: AppTheme.textSecondary,
                  ),
                  onPressed: _toggleDropdown,
                  splashRadius: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
