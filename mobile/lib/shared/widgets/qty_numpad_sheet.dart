import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile/core/theme/context_extension.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart' show SpeechListenOptions;

/// A premium numpad bottom-sheet specifically designed for quantity entry.
///
/// Usage:
/// ```dart
/// final qty = await showModalBottomSheet<num>(
///   context: context,
///   isScrollControlled: true,
///   backgroundColor: Colors.transparent,
///   builder: (_) => QtyNumpadSheet(
///     initial: 1.0,
///     itemName: 'Clutch Bearing',
///     rate: 550.0,
///     unit: 'NOS',
///   ),
/// );
/// ```
class QtyNumpadSheet extends StatefulWidget {
  final num initial;
  final String itemName;
  final String unit;
  final double rate;
  final bool isDecimal;

  const QtyNumpadSheet({
    super.key,
    required this.initial,
    required this.itemName,
    this.unit = 'NOS',
    this.rate = 0.0,
    this.isDecimal = false,
  });

  @override
  State<QtyNumpadSheet> createState() => _QtyNumpadSheetState();
}

class _QtyNumpadSheetState extends State<QtyNumpadSheet>
    with SingleTickerProviderStateMixin {
  String _digits = '';

  // Voice
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = true;
  bool _isListening = false;
  double _micPulse = 1.0;
  Timer? _pulseTimer;
  String _heardText = '';

  // Bounce animation for display scaling
  late final AnimationController _bounceCtrl;
  late final Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    // Start with empty digits so user can type immediately
    _digits = '';

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _bounceAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeOut),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) _bounceCtrl.reverse();
      });

    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      final ok = await _speech.initialize(
        onError: (_) {
          if (mounted) setState(() => _isListening = false);
          _pulseTimer?.cancel();
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _pulseTimer?.cancel();
            if (mounted) setState(() => _isListening = false);
          }
        },
      );
      if (mounted) setState(() => _speechAvailable = ok);
    } catch (_) {}
  }

  String _formatQty(num val) {
    if (widget.isDecimal) {
      return val % 1 == 0 ? val.toInt().toString() : val.toString();
    } else {
      return val.toInt().toString();
    }
  }

  double get _currentValue {
    if (_digits.isEmpty || _digits == '.') return 0.0;
    return double.tryParse(_digits) ?? 0.0;
  }

  // ── Keypad input ──────────────────────────────────────────────────────────

  void _onDigit(String d) {
    if (_digits.length >= 8) return; // Prevent unreasonable quantity length
    HapticFeedback.selectionClick();
    setState(() {
      if (_digits == '0' && d != '.') {
        _digits = d;
      } else {
        _digits += d;
      }
    });
    _triggerBounce();
  }

  void _onDecimalPoint() {
    if (!widget.isDecimal) return;
    if (_digits.contains('.')) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (_digits.isEmpty) {
        _digits = '0.';
      } else {
        _digits += '.';
      }
    });
    _triggerBounce();
  }

  void _onBackspace() {
    if (_digits.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _digits = _digits.substring(0, _digits.length - 1);
    });
  }

  void _onClear() {
    HapticFeedback.mediumImpact();
    setState(() {
      _digits = '';
      _heardText = '';
    });
  }

  void _triggerBounce() {
    if (!_bounceCtrl.isAnimating) _bounceCtrl.forward(from: 0);
  }



  // ── Voice ─────────────────────────────────────────────────────────────────

  Future<void> _startListening() async {
    if (_isListening) {
      _stopListening();
      return;
    }
    if (!_speechAvailable) {
      await _initSpeech();
      if (!_speechAvailable) return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _isListening = true;
      _micPulse = 1.0;
      _heardText = '';
    });

    _pulseTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _micPulse = _micPulse == 1.0 ? 1.4 : 1.0);
    });

    await _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: 'en-IN',
        listenFor: const Duration(seconds: 5),
        pauseFor: const Duration(milliseconds: 900),
        partialResults: true,
      ),
      onResult: (result) {
        if (!mounted) return;
        final raw = result.recognizedWords;
        if (raw.trim().isNotEmpty) {
          setState(() => _heardText = raw);
          final parsed = _parseSpokenQuantity(raw);
          if (parsed > 0) {
            setState(() => _digits = _formatQty(parsed));
            _triggerBounce();
          }
        }
        if (result.finalResult) _stopListening();
      },
    );
  }

  Future<void> _stopListening() async {
    _pulseTimer?.cancel();
    await _speech.stop();
    if (mounted) setState(() => _isListening = false);
  }

  num _parseSpokenQuantity(String raw) {
    if (raw.trim().isEmpty) return 0;
    final text = raw.toLowerCase().trim();

    final numberMap = {
      'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
      'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
      'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14,
      'fifteen': 15, 'sixteen': 16, 'seventeen': 17, 'eighteen': 18,
      'nineteen': 19, 'twenty': 20, 'thirty': 30, 'forty': 40,
      'fifty': 50, 'sixty': 60, 'seventy': 70, 'eighty': 80,
      'ninety': 90, 'hundred': 100,
      'ek': 1, 'don': 2, 'do': 2, 'teen': 3, 'tin': 3, 'char': 4,
      'paach': 5, 'saha': 6, 'chha': 6, 'saat': 7, 'aath': 8, 'nau': 9, 'nav': 9,
      'daha': 10
    };

    final directDouble = double.tryParse(text.replaceAll(RegExp(r'[^0-9.]'), ''));
    if (directDouble != null) return directDouble;

    final tokens = text.split(RegExp(r'\s+'));
    double value = 0;
    double currentTerm = 0;
    bool isFraction = false;
    double fractionMultiplier = 0.1;

    for (final token in tokens) {
      if (token == 'point' || token == 'dash' || token == 'dot' || token == 'decimal') {
        isFraction = true;
        continue;
      }

      final numValue = numberMap[token] ?? double.tryParse(token);
      if (numValue != null) {
        if (isFraction) {
          value += numValue * fractionMultiplier;
          fractionMultiplier *= 0.1;
        } else {
          if (currentTerm > 0 && numValue < 10) {
            currentTerm += numValue;
          } else {
            value += currentTerm;
            currentTerm = numValue.toDouble();
          }
        }
      }
    }
    value += currentTerm;
    return value;
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    _speech.stop();
    _bounceCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final value = _currentValue;
    final subtotal = value * widget.rate;
    final isValid = value > 0;

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header with Item Context
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.itemName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.rate > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Rate: ₹${widget.rate.toStringAsFixed(0)} / ${widget.unit}',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textSecondaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Large quantity number display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: AnimatedBuilder(
              animation: _bounceAnim,
              builder: (_, child) => Transform.scale(
                scale: _bounceAnim.value,
                child: child,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isValid
                      ? context.primaryColor.withValues(alpha: 0.08)
                      : _isListening
                          ? Colors.red.withValues(alpha: 0.06)
                          : context.primaryColor.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isValid
                        ? context.primaryColor.withValues(alpha: 0.4)
                        : _isListening
                            ? Colors.red.withValues(alpha: 0.35)
                            : context.borderColor,
                    width: isValid ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          _digits.isEmpty
                              ? Text(
                                  _isListening ? 'Speak quantity…' : '0',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: _isListening
                                        ? Colors.red.withValues(alpha: 0.7)
                                        : context.textSecondaryColor.withValues(
                                            alpha: 0.3,
                                          ),
                                  ),
                                )
                              : Text(
                                  _digits,
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: context.textColor,
                                  ),
                                ),
                          const SizedBox(width: 6),
                          Text(
                            widget.unit,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: context.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.rate > 0 && isValid)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: context.successColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$_digits × ₹${widget.rate.toStringAsFixed(0)} = ₹${subtotal.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: context.successColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Speech results banner
          if (_heardText.isNotEmpty && !_isListening)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: context.primaryColor.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.primaryColor.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.volume2, size: 14, color: context.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Voice input: "$_heardText"',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _heardText = ''),
                      child: Icon(LucideIcons.x, size: 14, color: context.textSecondaryColor),
                    ),
                  ],
                ),
              ),
            ),

          if (_isListening)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    AnimatedScale(
                      scale: _micPulse,
                      duration: const Duration(milliseconds: 300),
                      child: const Icon(LucideIcons.mic, size: 14, color: Colors.red),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Listening… say e.g., "ten" or "two point five"',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.withValues(alpha: 0.8),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _stopListening,
                      child: const Icon(LucideIcons.x, size: 14, color: Colors.red),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 12),

          // ── Numpad Grid ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _buildRow(['1', '2', '3'], context, isDark),
                const SizedBox(height: 8),
                _buildRow(['4', '5', '6'], context, isDark),
                const SizedBox(height: 8),
                _buildRow(['7', '8', '9'], context, isDark),
                const SizedBox(height: 8),
                // Bottom row: voice | 0 | backspace/decimal
                Row(
                  children: [
                    // Voice mic button
                    Expanded(
                      child: _NumpadKey(
                        isDark: isDark,
                        onTap: _speechAvailable ? _startListening : null,
                        highlighted: _isListening,
                        highlightColor: Colors.red,
                        child: AnimatedScale(
                          scale: _isListening ? _micPulse : 1.0,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isListening
                                  ? Colors.red
                                  : context.primaryColor.withValues(alpha: 0.12),
                              boxShadow: _isListening
                                  ? [
                                      BoxShadow(
                                        color: Colors.red.withValues(alpha: 0.4),
                                        blurRadius: 12,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Icon(
                              _isListening ? LucideIcons.micOff : LucideIcons.mic,
                              size: 18,
                              color: _isListening ? Colors.white : context.primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 0 button
                    Expanded(
                      child: _NumpadKey(
                        label: '0',
                        isDark: isDark,
                        disabled: _digits.length >= 8,
                        onTap: () => _onDigit('0'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Decimal point or Backspace
                    Expanded(
                      child: widget.isDecimal
                          ? _NumpadKey(
                              label: '.',
                              isDark: isDark,
                              disabled: _digits.contains('.'),
                              onTap: _onDecimalPoint,
                            )
                          : _NumpadKey(
                              isDark: isDark,
                              onTap: _digits.isEmpty ? null : _onBackspace,
                              onLongPress: _digits.isEmpty ? null : _onClear,
                              child: Icon(
                                LucideIcons.delete,
                                size: 20,
                                color: _digits.isEmpty
                                    ? context.textSecondaryColor.withValues(alpha: 0.3)
                                    : context.textColor,
                              ),
                            ),
                    ),
                  ],
                ),
                // Extra decimal line if decimal: show separate backspace
                if (widget.isDecimal) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Spacer(flex: 1),
                      Expanded(
                        flex: 1,
                        child: _NumpadKey(
                          isDark: isDark,
                          onTap: _digits.isEmpty ? null : _onBackspace,
                          onLongPress: _digits.isEmpty ? null : _onClear,
                          child: Icon(
                            LucideIcons.delete,
                            size: 20,
                            color: _digits.isEmpty
                                ? context.textSecondaryColor.withValues(alpha: 0.3)
                                : context.textColor,
                          ),
                        ),
                      ),
                      const Spacer(flex: 1),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Confirm CTA Button ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: isValid
                    ? () => Navigator.pop(context, widget.isDecimal ? value : value.toInt())
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isValid
                      ? context.primaryColor
                      : context.textSecondaryColor.withValues(alpha: 0.15),
                  foregroundColor: isValid ? Colors.white : context.textSecondaryColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isValid ? LucideIcons.checkCircle2 : LucideIcons.package,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isValid
                          ? 'Set Quantity'
                          : 'Enter a valid quantity',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Row _buildRow(List<String> digits, BuildContext context, bool isDark) {
    return Row(
      children: digits.asMap().entries.map((e) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: e.key == 0 ? 0 : 8),
            child: _NumpadKey(
              label: e.value,
              isDark: isDark,
              disabled: _digits.length >= 8,
              onTap: () => _onDigit(e.value),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _NumpadKey extends StatefulWidget {
  final String? label;
  final Widget? child;
  final bool isDark;
  final bool disabled;
  final bool highlighted;
  final Color? highlightColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _NumpadKey({
    this.label,
    this.child,
    required this.isDark,
    this.disabled = false,
    this.highlighted = false,
    this.highlightColor,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<_NumpadKey> createState() => _NumpadKeyState();
}

class _NumpadKeyState extends State<_NumpadKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final pressColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.1);

    return GestureDetector(
      onTapDown: widget.disabled || widget.onTap == null
          ? null
          : (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.disabled || widget.onTap == null ? null : widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        height: 52, // compact 52 height for quantity numpad
        decoration: BoxDecoration(
          color: widget.highlighted
              ? (widget.highlightColor ?? context.primaryColor).withValues(alpha: 0.1)
              : _pressed
                  ? pressColor
                  : baseColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.highlighted
                ? (widget.highlightColor ?? context.primaryColor).withValues(alpha: 0.3)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Center(
          child: widget.child ??
              Text(
                widget.label ?? '',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: widget.disabled
                      ? context.textSecondaryColor.withValues(alpha: 0.25)
                      : context.textColor,
                ),
              ),
        ),
      ),
    );
  }
}
