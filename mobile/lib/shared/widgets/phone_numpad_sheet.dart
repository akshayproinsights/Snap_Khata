import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile/core/theme/context_extension.dart';
import 'package:mobile/core/utils/contact_utils.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart' show SpeechListenOptions;

/// A premium numpad bottom-sheet for phone number entry.
///
/// Usage:
/// ```dart
/// final phone = await showModalBottomSheet<String>(
///   context: context,
///   isScrollControlled: true,
///   backgroundColor: Colors.transparent,
///   builder: (_) => PhoneNumpadSheet(initial: '9876543210'),
/// );
/// if (phone != null) { ... }
/// ```
class PhoneNumpadSheet extends StatefulWidget {
  /// Pre-filled number (without +91 prefix), can be empty.
  final String initial;
  /// Label shown at the top of the sheet.
  final String title;

  const PhoneNumpadSheet({
    super.key,
    this.initial = '',
    this.title = 'Enter Mobile Number',
  });

  @override
  State<PhoneNumpadSheet> createState() => _PhoneNumpadSheetState();
}

class _PhoneNumpadSheetState extends State<PhoneNumpadSheet>
    with SingleTickerProviderStateMixin {
  String _digits = '';

  // Voice
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = true;
  bool _isListening = false;
  double _micPulse = 1.0;
  Timer? _pulseTimer;
  String _heardText = '';

  // Bounce animation for new digits
  late final AnimationController _bounceCtrl;
  late final Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    // Sanitize the initial value
    _digits = widget.initial.replaceAll(RegExp(r'[^0-9]'), '');
    if (_digits.length > 10) _digits = _digits.substring(_digits.length - 10);

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _bounceAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
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

  // ── Numpad input ──────────────────────────────────────────────────────────

  void _onDigit(String d) {
    if (_digits.length >= 10) return;
    HapticFeedback.selectionClick();
    setState(() => _digits += d);
    if (!_bounceCtrl.isAnimating) _bounceCtrl.forward(from: 0);
  }

  void _onBackspace() {
    if (_digits.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  void _onClear() {
    HapticFeedback.mediumImpact();
    setState(() {
      _digits = '';
      _heardText = '';
    });
  }

  // ── Voice ─────────────────────────────────────────────────────────────────

  Future<void> _startListening() async {
    if (_isListening) { _stopListening(); return; }
    if (!_speechAvailable) {
      // Retry init
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
        listenFor: const Duration(seconds: 8),
        // ⚡ 800ms pause = feels instant vs 3s default
        pauseFor: const Duration(milliseconds: 800),
        partialResults: true,
      ),
      onResult: (result) {
        if (!mounted) return;
        final raw = result.recognizedWords;
        if (raw.trim().isNotEmpty) {
          setState(() => _heardText = raw);
          final parsed = _parseSpokenMobileNumber(raw);
          if (parsed.isNotEmpty) {
            setState(() => _digits = parsed);
            if (!_bounceCtrl.isAnimating) _bounceCtrl.forward(from: 0);
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

  // ── Contact picker ────────────────────────────────────────────────────────

  Future<void> _pickContact() async {
    final phone = await ContactUtils.pickContactPhone();
    if (phone != null && mounted) {
      final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
      final last10 = cleaned.length > 10
          ? cleaned.substring(cleaned.length - 10)
          : cleaned;
      setState(() {
        _digits = last10;
        _heardText = '';
      });
      if (!_bounceCtrl.isAnimating) _bounceCtrl.forward(from: 0);
    }
  }

  // ── Number-word parser (Marathi + English) ────────────────────────────────

  String _parseSpokenMobileNumber(String raw) {
    if (raw.trim().isEmpty) return '';

    const marathiTens = {
      'vis': 20, 'vees': 20, 'wees': 20,
      'tees': 30, 'this': 30,
      'challees': 40, 'chalis': 40, 'chhalees': 40,
      'pannhas': 50, 'pannas': 50, 'panas': 50,
      'saath': 60, 'saatth': 60, 'sath': 60, 'saahath': 60,
      'sattar': 70, 'satar': 70,
      'ashi': 80, 'aashi': 80,
      'nabbad': 90, 'navad': 90, 'nabbud': 90,
    };

    const digitWords = {
      'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4,
      'five': 5, 'six': 6, 'seven': 7, 'eight': 8, 'nine': 9,
      'ek': 1, 'shunya': 0, 'don': 2, 'do': 2, 'dohn': 2,
      'teen': 3, 'tin': 3, 'char': 4,
      'paach': 5, 'panch': 5, 'paanch': 5,
      'saha': 6, 'chha': 6, 'che': 6,
      'aath': 8, 'aatth': 8, 'nau': 9, 'nav': 9,
    };

    const englishTens = {
      'ten': 10, 'eleven': 11, 'twelve': 12, 'thirteen': 13,
      'fourteen': 14, 'fifteen': 15, 'sixteen': 16, 'seventeen': 17,
      'eighteen': 18, 'nineteen': 19,
      'twenty': 20, 'thirty': 30, 'forty': 40, 'fifty': 50,
      'sixty': 60, 'seventy': 70, 'eighty': 80, 'ninety': 90,
    };

    const marathiCompound = {
      'ekvis': 21, 'bavis': 22, 'teyvis': 23, 'chauvis': 24,
      'panchvis': 25, 'savis': 26, 'sataavis': 27, 'atthavis': 28, 'ekonatis': 29,
      'ekatis': 31, 'battis': 32, 'battees': 32, 'tettis': 33, 'chautis': 34,
      'pentis': 35, 'chattis': 36, 'settis': 37, 'apphatthis': 38, 'ekonchalis': 39,
      'ekchalis': 41, 'bechalis': 42, 'trechalis': 43, 'chaucalis': 44,
      'panchechalis': 45, 'sehechalis': 46, 'sataachalis': 47, 'atthaachalis': 48, 'ekonpannas': 49,
      'ekavan': 51, 'bavan': 52, 'trevan': 53, 'chavan': 54, 'chauvan': 54,
      'panchavan': 55, 'sahavan': 56, 'sattavan': 57, 'athhavan': 58, 'ekonsaath': 59,
      'eksaath': 61, 'basaath': 62, 'tresaath': 63, 'chausaath': 64,
      'pansaath': 65, 'sahesaath': 66, 'satsaath': 67, 'atthsaath': 68, 'ekonsattar': 69,
      'eksattar': 71, 'basattar': 72, 'tresattar': 73, 'chausattar': 74,
      'pansattar': 75, 'sahesattar': 76, 'shahattar': 76, 'satsattar': 77, 'atthasattar': 78, 'ekonashi': 79,
      'ekaashi': 81, 'byasi': 82, 'treashi': 83, 'chorashi': 84,
      'panchaashi': 85, 'sahashi': 86, 'sataashi': 87, 'athhashi': 88, 'ekonanabba': 89,
      'ekanabba': 91, 'banabba': 92, 'trenabba': 93, 'chaunabba': 94,
      'panchananabba': 95, 'shahanabba': 96, 'sattaanabba': 97,
      'aathyanabba': 98, 'aathyanab': 98, 'navaanabba': 99,
    };

    final tokens = raw.toLowerCase().trim()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    final nums = <int>[];
    int i = 0;
    while (i < tokens.length) {
      final t = tokens[i];
      final asInt = int.tryParse(t);
      if (asInt != null) { nums.add(asInt); i++; continue; }
      if (marathiCompound.containsKey(t)) { nums.add(marathiCompound[t]!); i++; continue; }
      if (marathiTens.containsKey(t)) { nums.add(marathiTens[t]!); i++; continue; }
      if (englishTens.containsKey(t)) {
        int val = englishTens[t]!;
        if (i + 1 < tokens.length) {
          final nd = digitWords[tokens[i + 1]];
          if (nd != null && val >= 20) { nums.add(val + nd); i += 2; continue; }
        }
        nums.add(val); i++; continue;
      }
      if (digitWords.containsKey(t)) { nums.add(digitWords[t]!); i++; continue; }
      i++;
    }

    if (nums.isEmpty) return '';
    final sb = StringBuffer();
    for (final n in nums) { sb.write(n.toString()); }
    final digits = sb.toString().replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
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
    final isValid = _digits.length == 10;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
          // ── Drag handle ───────────────────────────────────────────────────
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

          // ── Header ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                if (ContactUtils.isSupported)
                  IconButton(
                    icon: Icon(
                      LucideIcons.contact,
                      color: context.primaryColor,
                      size: 22,
                    ),
                    tooltip: 'Pick from contacts',
                    onPressed: _pickContact,
                  ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // ── Number display ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: AnimatedBuilder(
              animation: _bounceAnim,
              builder: (_, child) => Transform.scale(
                scale: _bounceAnim.value,
                child: child,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: isValid
                      ? context.successColor.withValues(alpha: 0.08)
                      : _isListening
                          ? Colors.red.withValues(alpha: 0.06)
                          : context.primaryColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isValid
                        ? context.successColor.withValues(alpha: 0.4)
                        : _isListening
                            ? Colors.red.withValues(alpha: 0.35)
                            : context.primaryColor.withValues(alpha: 0.2),
                    width: isValid ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // +91 badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isValid
                            ? context.successColor.withValues(alpha: 0.12)
                            : context.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '+91',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: isValid
                              ? context.successColor
                              : context.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Digit display
                    Expanded(
                      child: _digits.isEmpty
                          ? Text(
                              _isListening
                                  ? 'Bol... number sanga 🎙'
                                  : '_ _ _ _ _ _ _ _ _ _',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                                color: _isListening
                                    ? Colors.red.withValues(alpha: 0.7)
                                    : context.textSecondaryColor.withValues(
                                        alpha: 0.35,
                                      ),
                              ),
                            )
                          : Text(
                              _formatDisplay(_digits),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.5,
                                color: isValid
                                    ? context.successColor
                                    : context.textColor,
                              ),
                            ),
                    ),
                    // Status icon
                    if (_digits.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: isValid
                            ? Icon(
                                LucideIcons.checkCircle2,
                                color: context.successColor,
                                size: 22,
                              )
                            : Text(
                                '${_digits.length}/10',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: context.textSecondaryColor,
                                ),
                              ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── Voice "I heard" banner ─────────────────────────────────────────
          if (_heardText.isNotEmpty && !_isListening)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: context.primaryColor.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.primaryColor.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.volume2, size: 14, color: context.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Heard: "$_heardText"',
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
                      child: Icon(
                        LucideIcons.x,
                        size: 14,
                        color: context.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_isListening)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                        'Listening... say digits, pairs, or Marathi numbers',
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

          const SizedBox(height: 8),

          // ── Numpad grid ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                _buildRow(['1', '2', '3'], context, isDark),
                const SizedBox(height: 10),
                _buildRow(['4', '5', '6'], context, isDark),
                const SizedBox(height: 10),
                _buildRow(['7', '8', '9'], context, isDark),
                const SizedBox(height: 10),
                // Bottom row: voice | 0 | backspace
                Row(
                  children: [
                    // Voice button
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
                              color: _isListening
                                  ? Colors.white
                                  : context.primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 0 button
                    Expanded(
                      child: _NumpadKey(
                        label: '0',
                        isDark: isDark,
                        disabled: _digits.length >= 10,
                        onTap: () => _onDigit('0'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Backspace
                    Expanded(
                      child: _NumpadKey(
                        isDark: isDark,
                        onTap: _digits.isEmpty ? null : _onBackspace,
                        onLongPress: _digits.isEmpty ? null : _onClear,
                        child: Icon(
                          LucideIcons.delete,
                          size: 22,
                          color: _digits.isEmpty
                              ? context.textSecondaryColor.withValues(alpha: 0.3)
                              : context.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Confirm button ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: isValid
                    ? () => Navigator.pop(context, _digits)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isValid
                      ? context.primaryColor
                      : context.textSecondaryColor.withValues(alpha: 0.15),
                  foregroundColor: isValid
                      ? Colors.white
                      : context.textSecondaryColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isValid ? LucideIcons.checkCircle2 : LucideIcons.phone,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isValid
                          ? 'Use +91 $_digits'
                          : '${10 - _digits.length} more digit${10 - _digits.length == 1 ? '' : 's'} needed',
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
          SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
        ],
      ),
    );
  }

  Row _buildRow(List<String> digits, BuildContext context, bool isDark) {
    return Row(
      children: digits.asMap().entries.map((e) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: e.key == 0 ? 0 : 10),
            child: _NumpadKey(
              label: e.value,
              isDark: isDark,
              disabled: _digits.length >= 10,
              onTap: () => _onDigit(e.value),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Formats 10 digits as "98765 43210" for readability.
  String _formatDisplay(String d) {
    if (d.length <= 5) return d;
    return '${d.substring(0, 5)} ${d.substring(5)}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// Single numpad key — large touch target, subtle press animation.
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
        height: 64,
        decoration: BoxDecoration(
          color: widget.highlighted
              ? (widget.highlightColor ?? context.primaryColor).withValues(alpha: 0.1)
              : _pressed
                  ? pressColor
                  : baseColor,
          borderRadius: BorderRadius.circular(16),
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
                  fontSize: 24,
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
