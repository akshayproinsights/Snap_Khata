import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:mobile/features/udhar/presentation/providers/udhar_provider.dart';
import 'package:mobile/features/inventory/presentation/providers/vendor_ledger_provider.dart';
import 'package:mobile/features/udhar/presentation/providers/item_catalogue_provider.dart';
import 'package:mobile/features/udhar/presentation/pages/item_catalogue_page.dart';
import 'package:mobile/features/settings/presentation/providers/shop_provider.dart';
import 'package:mobile/features/udhar/domain/models/udhar_models.dart';
import 'package:mobile/features/inventory/domain/models/vendor_ledger_models.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/theme/context_extension.dart';
import 'package:mobile/core/widgets/editable_qty_stepper.dart';
import 'package:mobile/core/utils/whatsapp_utils.dart';
import 'package:mobile/core/utils/contact_utils.dart';
import 'package:mobile/shared/widgets/app_toast.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart' show SpeechListenOptions;
import 'package:fuzzy/fuzzy.dart';
import 'package:mobile/shared/widgets/phone_numpad_sheet.dart';


class AddPartyEntrySheet extends ConsumerStatefulWidget {
  final List<CatalogueCartItem>? initialItems;
  final CustomerLedger? initialCustomer;
  final VendorLedger? initialVendor;
  final String? initialPartyType;

  const AddPartyEntrySheet({
    super.key,
    this.initialItems,
    this.initialCustomer,
    this.initialVendor,
    this.initialPartyType,
  });

  @override
  ConsumerState<AddPartyEntrySheet> createState() => _AddPartyEntrySheetState();
}

class _ManualItem {
  String name;
  double quantity;
  double rate;
  String unit;
  /// True when this item was added via voice and is NOT in the catalogue (new item).
  bool isNew;
  late final TextEditingController rateController;
  late final FocusNode rateFocusNode;

  _ManualItem({
    required this.name,
    this.quantity = 1.0,
    this.rate = 0.0,
    this.unit = '',
    this.isNew = false,
  }) {
    rateController = TextEditingController(
      text: rate > 0 ? rate.toStringAsFixed(0) : '',
    );
    rateFocusNode = FocusNode();
  }

  void dispose() {
    rateController.dispose();
    rateFocusNode.dispose();
  }

  Map<String, dynamic> toJson() => {
    'item_name': name,
    'quantity': quantity,
    'rate': rate,
    'amount': quantity * rate,
    'unit': unit,
  };
}

class _AddPartyEntrySheetState extends ConsumerState<AddPartyEntrySheet>
    with SingleTickerProviderStateMixin {
  final _partySearchController = TextEditingController();
  final _flatAmountController = TextEditingController();
  final _notesController = TextEditingController();
  final _mobileController = TextEditingController();
  final _paidAmountController = TextEditingController();
  final FocusNode _partySearchFocusNode = FocusNode();
  final FocusNode _mobileFocusNode = FocusNode();

  String _partyType = 'customer'; // 'customer' or 'vendor'
  String _entryType =
      'gave'; // 'got' or 'gave' — defaults to 'gave' (sale mode)
  String _paymentMode =
      'Credit'; // 'Credit', 'Cash', 'UPI' — only used when entry_type=='gave'
  DateTime _selectedDate = DateTime.now();
  DateTime? _deliveryDate;
  bool _isLoading = false;

  // Selected party details
  CustomerLedger? _selectedCustomer;
  VendorLedger? _selectedVendor;
  bool _showSuggestions = false;

  // ── Voice search (customer name) ─────────────────────────────────────────
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = true;
  bool _isListening = false;
  String _heardText = ''; // raw transcript shown to user
  Timer? _voicePulseTimer;
  double _micPulse = 1.0; // scale for animated mic ring

  // ── Voice input (item list) ───────────────────────────────────────────────
  bool _isItemListening = false;
  Timer? _itemVoiceTimer;
  double _itemMicPulse = 1.0;

  // ── Inline "New Item" form ────────────────────────────────────────────────
  bool _showInlineNewItem = false;
  final _inlineItemNameController = TextEditingController();
  final _inlineItemRateController = TextEditingController();
  double _inlineItemQty = 1.0;

  // ─────────────────────────────────────────────────────────────────────────


  // Line items list
  final List<_ManualItem> _items = [];

  // Animated total tracking
  late final AnimationController _totalBumpController;
  late final Animation<double> _totalBumpAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.initialPartyType != null) {
      _partyType = widget.initialPartyType!;
    }
    if (widget.initialCustomer != null) {
      _partyType = 'customer';
      _selectedCustomer = widget.initialCustomer;
      _partySearchController.text = widget.initialCustomer!.customerName;
      if (widget.initialCustomer!.customerPhone != null &&
          widget.initialCustomer!.customerPhone!.isNotEmpty) {
        _mobileController.text = widget.initialCustomer!.customerPhone!
            .replaceAll('+91', '')
            .trim();
      }
    }
    if (widget.initialVendor != null) {
      _partyType = 'vendor';
      _selectedVendor = widget.initialVendor;
      _partySearchController.text = widget.initialVendor!.vendorName;
    }
    if (widget.initialItems != null) {
      _items.addAll(
        widget.initialItems!.map(
          (ci) => _ManualItem(
            name: ci.name,
            rate: ci.rate,
            unit: ci.unit,
            quantity: ci.qty.toDouble(),
          ),
        ),
      );
    }
    _totalBumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _totalBumpAnimation =
        Tween<double>(begin: 1.0, end: 1.18).animate(
          CurvedAnimation(parent: _totalBumpController, curve: Curves.easeOut),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _totalBumpController.reverse();
          }
        });

    _partySearchController.addListener(() {
      if (_partySearchController.text.trim().isNotEmpty &&
          _partySearchFocusNode.hasFocus) {
        setState(() {
          _showSuggestions = true;
        });
      } else {
        setState(() {
          _showSuggestions = false;
        });
      }
    });

    _partySearchFocusNode.addListener(() {
      if (!_partySearchFocusNode.hasFocus) {
        // Delay hiding suggestions so that a tap on a suggestion item
        // is registered BEFORE the list disappears (focus fires before onTap).
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() {
              _showSuggestions = false;
            });
          }
        });
      } else {
        setState(() {
          _showSuggestions = _partySearchController.text.trim().isNotEmpty;
        });
      }
    });

    // Initialise speech engine silently (does not block UI)
    _initSpeechSilently();
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    _totalBumpController.dispose();
    _partySearchController.dispose();
    _flatAmountController.dispose();
    _notesController.dispose();
    _partySearchFocusNode.dispose();
    _mobileController.dispose();
    _paidAmountController.dispose();
    _mobileFocusNode.dispose();
    _voicePulseTimer?.cancel();
    _itemVoiceTimer?.cancel();
    _speech.stop();
    _inlineItemNameController.dispose();
    _inlineItemRateController.dispose();
    super.dispose();
  }

  // ── Voice / Fuzzy helpers ─────────────────────────────────────────────────────

  Future<void> _initSpeechSilently() async {
    try {
      final ok = await _speech.initialize(
        onError: (e) {
          if (mounted) {
            setState(() {
              _isListening = false;
              _isItemListening = false;
            });
          }
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) {
              setState(() {
                _isListening = false;
                _isItemListening = false;
              });
            }
            _voicePulseTimer?.cancel();
            _itemVoiceTimer?.cancel();
          }
        },
      );
      if (ok && mounted) {
        setState(() => _speechAvailable = true);
      }
    } catch (_) {}
  }

  Future<bool> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onError: (e) {
          if (mounted) {
            setState(() {
              _isListening = false;
              _isItemListening = false;
            });
          }
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) {
              setState(() {
                _isListening = false;
                _isItemListening = false;
              });
            }
            _voicePulseTimer?.cancel();
            _itemVoiceTimer?.cancel();
          }
        },
      );
      if (mounted) setState(() => _speechAvailable = available);
      return available;
    } catch (e) {
      if (mounted) setState(() => _speechAvailable = false);
      return false;
    }
  }

  Future<bool> _ensureSpeechInitialized() async {
    if (_speech.isAvailable) return true;
    final ok = await _initSpeech();
    if (!ok) {
      _showPermissionHelpDialog();
    }
    return ok;
  }

  void _showPermissionHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.mic_off, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text(
              'Microphone Blocked',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To use voice input, this app needs microphone permission.',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Text(
              'How to enable:',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('1. ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text(
                    'Tap the lock/security icon next to the URL in your browser address bar.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('2. ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text(
                    'Find "Microphone" in the list and switch it to "Allow" (or clear the Blocked setting).',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('3. ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text(
                    'Reload the page/app and tap the microphone icon again.',
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: context.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startListening() async {
    final ok = await _ensureSpeechInitialized();
    if (!ok) return;
    if (_isListening) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isListening = true;
      _heardText = '';
    });

    // Animate the mic pulse ring
    _voicePulseTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (mounted) {
        setState(() {
          _micPulse = _micPulse == 1.0 ? 1.35 : 1.0;
        });
      }
    });

    // en-IN handles Indian English names (Akshay, Ramesh, etc.) naturally.
    // Filler words are stripped in _processHeardText below.
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: 'en-IN',
        listenFor: const Duration(seconds: 6),
        pauseFor: const Duration(seconds: 2),
        partialResults: true,
      ),
      onResult: (result) {
        if (!mounted) return;
        final raw = result.recognizedWords;
        final cleaned = _processHeardText(raw);
        setState(() {
          _heardText = raw;
          _partySearchController.text = cleaned;
          _showSuggestions = cleaned.isNotEmpty;
        });
      },
    );
  }


  Future<void> _stopListening() async {
    _voicePulseTimer?.cancel();
    await _speech.stop();
    if (mounted) setState(() => _isListening = false);
  }

  // ── Item list voice methods ───────────────────────────────────────────────

  // ignore: unused_element
  Future<void> _startItemListening(List<CatalogueItem> catalogue) async {
    final ok = await _ensureSpeechInitialized();
    if (!ok) return;
    if (_isItemListening || _isListening) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isItemListening = true;
      _itemMicPulse = 1.0;
    });

    _itemVoiceTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (mounted) {
        setState(() {
          _itemMicPulse = _itemMicPulse == 1.0 ? 1.35 : 1.0;
        });
      }
    });

    await _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: 'en-IN',
        listenFor: const Duration(seconds: 12),
        pauseFor: const Duration(seconds: 3),
        partialResults: false,
      ),
      onResult: (result) async {
        if (!mounted) return;
        if (result.finalResult) {
          _stopItemListening();
          final transcript = result.recognizedWords;
          if (transcript.trim().isEmpty) return;

          // ── Gemini-first parse ────────────────────────────────────────────
          // Try the backend AI endpoint. On any failure (offline, error, empty
          // result) silently fall back to the local regex parser.
          List<_ManualItem> parsed = [];
          try {
            parsed = await _parseItemsWithGemini(transcript, catalogue);
          } catch (_) {
            parsed = [];
          }

          // ── Local regex fallback ──────────────────────────────────────────
          if (parsed.isEmpty) {
            parsed = _parseVoiceItems(transcript, catalogue);
          }

          if (parsed.isNotEmpty && mounted) {
            setState(() {
              _items.addAll(parsed);
            });
            _bumpTotal();
            AppToast.showSuccess(
              context,
              '${parsed.length} item${parsed.length == 1 ? '' : 's'} added 🎉',
            );
          }
        }
      },
    );
  }

  Future<void> _stopItemListening() async {
    _itemVoiceTimer?.cancel();
    await _speech.stop();
    if (mounted) setState(() => _isItemListening = false);
  }

  /// Call the backend `/api/voice/parse-items` endpoint.
  /// Returns an empty list on any error so the caller falls back to regex.
  Future<List<_ManualItem>> _parseItemsWithGemini(
    String transcript,
    List<CatalogueItem> catalogue,
  ) async {
    final response = await ApiClient().dio.post(
      '/api/voice/parse-items',
      data: {
        'transcript': transcript,
        'catalogue_names': catalogue.map((c) => c.itemName).toList(),
      },
    );

    final status = response.data['status'] as String? ?? '';
    if (status != 'success') return [];

    final rawItems = response.data['items'] as List<dynamic>? ?? [];
    if (rawItems.isEmpty) return [];

    final results = <_ManualItem>[];
    for (final it in rawItems) {
      final name = (it['name'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      final qty = (it['quantity'] as num?)?.toDouble() ?? 1.0;
      String unit = (it['unit'] as String? ?? '').toUpperCase();
      if (unit == 'NOS') {
        unit = '';
      }

      // Try to match returned name against catalogue for price autofill
      final catalogueMatch = _matchCatalogueItem(name, catalogue);
      if (catalogueMatch != null) {
        final catUnit = catalogueMatch.unit == 'NOS' ? '' : catalogueMatch.unit;
        results.add(
          _ManualItem(
            name: catalogueMatch.itemName,
            quantity: qty,
            rate: catalogueMatch.lastPrice,
            unit: unit.isEmpty ? catUnit : unit,
            isNew: false,
          )..rateController.text = catalogueMatch.lastPrice > 0
              ? catalogueMatch.lastPrice.toStringAsFixed(0)
              : '',
        );
      } else {
        results.add(
          _ManualItem(
            name: name,
            quantity: qty,
            rate: 0.0,
            unit: unit,
            isNew: true,
          ),
        );
      }
    }
    return results;
  }


  /// Parse voice utterance into a list of _ManualItem entries.
  ///
  /// Handles patterns like:
  ///   "2 kg atta, 5 litre oil, 3 soap"
  ///   "ek atta do oil teen soap" (number words)
  ///   "atta 2, oil 5, soap" (name-first format)
  List<_ManualItem> _parseVoiceItems(
    String raw,
    List<CatalogueItem> catalogue,
  ) {
    if (raw.trim().isEmpty) return [];

    // Number-word map (Hindi/English)
    const numWords = {
      'ek': 1, 'one': 1, 'do': 2, 'two': 2, 'teen': 3, 'three': 3,
      'char': 4, 'four': 4, 'paanch': 5, 'five': 5, 'chhe': 6, 'six': 6,
      'saat': 7, 'seven': 7, 'aath': 8, 'eight': 8, 'nau': 9, 'nine': 9,
      'das': 10, 'ten': 10, 'barah': 12, 'twelve': 12, 'pachas': 50,
      'fifty': 50, 'sou': 100, 'hundred': 100,
    };

    // Known unit words to strip from item name
    const unitWords = {
      'kg': 'KG', 'kilo': 'KG', 'kilogram': 'KG', 'kilograms': 'KG',
      'gm': 'GM', 'gram': 'GM', 'grams': 'GM', 'g': 'GM',
      'ltr': 'LTR', 'litre': 'LTR', 'litres': 'LTR', 'liter': 'LTR',
      'liters': 'LTR', 'l': 'LTR',
      'ml': 'ML', 'milliliter': 'ML', 'millilitre': 'ML',
      'pcs': '', 'piece': '', 'pieces': '', 'nos': '',
      'packet': 'PKT', 'packets': 'PKT', 'pkt': 'PKT',
      'box': 'BOX', 'boxes': 'BOX',
      'dozen': 'DOZ', 'doz': 'DOZ',
    };

    // Split by comma, "and", or "aur"
    final segments = raw
        .toLowerCase()
        .split(RegExp(r',|\band\b|\baur\b'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final results = <_ManualItem>[];

    for (final seg in segments) {
      final tokens = seg.trim().split(RegExp(r'\s+'));
      if (tokens.isEmpty) continue;

      double qty = 1.0;
      String unit = '';
      final nameTokens = <String>[];

      int i = 0;
      // Try to extract a leading quantity (numeric or word)
      if (i < tokens.length) {
        final t = tokens[i];
        final parsed = double.tryParse(t) ?? numWords[t]?.toDouble();
        if (parsed != null) {
          qty = parsed;
          i++;
        }
      }
      // Try to extract a unit word
      if (i < tokens.length && unitWords.containsKey(tokens[i])) {
        unit = unitWords[tokens[i]]!;
        i++;
      }
      // Remaining tokens are the item name
      while (i < tokens.length) {
        final t = tokens[i];
        // Trailing quantity (e.g. "atta 2")
        if (nameTokens.isNotEmpty && double.tryParse(t) != null) {
          qty = double.parse(t);
        } else if (!unitWords.containsKey(t)) {
          nameTokens.add(t);
        }
        i++;
      }

      if (nameTokens.isEmpty) continue;

      final rawName = nameTokens
          .map((w) => w[0].toUpperCase() + w.substring(1))
          .join(' ');

      // Try to fuzzy-match against catalogue
      final catalogueMatch = _matchCatalogueItem(rawName, catalogue);

      if (catalogueMatch != null) {
        final catUnit = catalogueMatch.unit == 'NOS' ? '' : catalogueMatch.unit;
        results.add(
          _ManualItem(
            name: catalogueMatch.itemName,
            quantity: qty,
            rate: catalogueMatch.lastPrice,
            unit: unit.isEmpty ? catUnit : unit,
            isNew: false,
          )..rateController.text = catalogueMatch.lastPrice > 0
              ? catalogueMatch.lastPrice.toStringAsFixed(0)
              : '',
        );
      } else {
        // New item — not in catalogue, highlight it
        results.add(
          _ManualItem(
            name: rawName,
            quantity: qty,
            rate: 0.0,
            unit: unit,
            isNew: true,
          ),
        );
      }
    }

    return results;
  }

  /// Fuzzy-match a raw voice name against the catalogue.
  /// Returns null if no close match found.
  CatalogueItem? _matchCatalogueItem(
    String rawName,
    List<CatalogueItem> catalogue,
  ) {
    if (catalogue.isEmpty) return null;
    final q = rawName.toLowerCase();

    // 1. Exact match
    for (final item in catalogue) {
      if (item.itemName.toLowerCase() == q) return item;
    }
    // 2. Starts-with
    for (final item in catalogue) {
      if (item.itemName.toLowerCase().startsWith(q)) return item;
    }
    // 3. Contains
    for (final item in catalogue) {
      if (item.itemName.toLowerCase().contains(q)) return item;
    }
    // 4. Any catalogue item contains the query word
    for (final item in catalogue) {
      if (q.contains(item.itemName.toLowerCase())) return item;
    }
    // 5. Fuzzy
    final fuse = Fuzzy<String>(
      catalogue.map((c) => c.itemName.toLowerCase()).toList(),
      options: FuzzyOptions(threshold: 0.5, distance: 100),
    );
    final hits = fuse.search(q);
    if (hits.isNotEmpty) {
      final matched = hits.first.item;
      return catalogue.firstWhere(
        (c) => c.itemName.toLowerCase() == matched,
        orElse: () => catalogue.first,
      );
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────

  /// Strip Hindi/Marathi filler words so "Akshay bhai ka naam" → "Akshay"
  String _processHeardText(String raw) {
    const fillers = [
      'bhai', 'bhaiya', 'ka', 'naam', 'wala', 'wali', 'ji',
      'sahab', 'saheb', 'seth', 'dada', 'didi', 'tai', 'kaka',
      'mama', 'mami', 'nana', 'nani', 'bai', 'anna',
    ];
    final words = raw.trim().toLowerCase().split(RegExp(r'\s+'));
    final meaningful = words.where((w) => w.isNotEmpty && !fillers.contains(w)).toList();
    if (meaningful.isEmpty) return raw.trim();
    // Capitalize first letter of each word for name display
    return meaningful.map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  /// Fuzzy-ranked customer search using the `fuzzy` package.
  /// Returns customers sorted by match score descending.
  List<CustomerLedger> _fuzzySearchCustomers(
    String query,
    List<CustomerLedger> all,
  ) {
    if (query.isEmpty) return all;
    final q = query.toLowerCase().trim();

    // Score each customer
    final scored = all.map((c) {
      final name = c.customerName.toLowerCase();
      double score = 0.0;

      // Exact match
      if (name == q) {
        score = 1.0;
      // Starts with query
      } else if (name.startsWith(q)) {
        score = 0.9;
      // Contains query
      } else if (name.contains(q)) {
        score = 0.75;
      } else {
        // Fuzzy: use fuzzy package for similarity
        final fuse = Fuzzy<String>(
          [name],
          options: FuzzyOptions(
            threshold: 0.6,
            distance: 100,
            tokenize: false,
          ),
        );
        final results = fuse.search(q);
        if (results.isNotEmpty) {
          // Fuzzy score is 0 (perfect) to 1 (no match) — invert it
          score = math.max(0.0, 1.0 - results.first.score);
        }
        // Also check phone number match
        if (c.customerPhone != null && c.customerPhone!.contains(q)) {
          score = math.max(score, 0.7);
        }
      }
      return (customer: c, score: score);
    }).toList();

    // Filter out near-zero matches and sort by score descending
    scored.removeWhere((e) => e.score < 0.25);
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((e) => e.customer).toList();
  }

  // ─────────────────────────────────────────────────────────────────────────

  void _bumpTotal() {
    if (!_totalBumpController.isAnimating) {
      _totalBumpController.forward(from: 0);
    }
  }

  Future<void> _openQuickBill() async {
    final result = await Navigator.push<List<CatalogueCartItem>>(
      context,
      MaterialPageRoute(
        builder: (_) => const ItemCataloguePage(selectionMode: true),
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      setState(() {
        _items.addAll(
          result.map(
            (ci) => _ManualItem(
              name: ci.name,
              rate: ci.rate,
              unit: ci.unit,
              quantity: ci.qty.toDouble(),
            ),
          ),
        );
      });
      _bumpTotal();
    }
  }

  Widget _buildInlineNewItemForm(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.primaryColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: context.primaryColor.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item Name
          TextField(
            controller: _inlineItemNameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Item Name',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: context.borderColor,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: context.primaryColor),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Qty + Rate row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Qty stepper
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Qty',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondaryColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  EditableQtyStepper(
                    qty: _inlineItemQty,
                    btnSize: 36.0,
                    boxWidth: 48.0,
                    boxHeight: 44.0,
                    isDecimal: false,
                    showTrashAtOne: false,
                    itemName: _inlineItemNameController.text.trim().isEmpty
                        ? 'Item'
                        : _inlineItemNameController.text.trim(),
                    rate: double.tryParse(
                          _inlineItemRateController.text.trim(),
                        ) ??
                        0.0,
                    unit: '',
                    onChanged: (newQty) {
                      setState(() {
                        _inlineItemQty = newQty.toDouble();
                      });
                    },
                    onDecrement: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        if (_inlineItemQty > 1) _inlineItemQty -= 1;
                      });
                    },
                    onIncrement: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _inlineItemQty += 1;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Rate
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rate (₹)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 44,
                      child: TextField(
                        controller: _inlineItemRateController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          hintText: '0',
                          prefixText: '₹',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: context.borderColor),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: context.primaryColor),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final name = _inlineItemNameController.text.trim();
                if (name.isEmpty) {
                  AppToast.showError(context, 'Please enter item name');
                  return;
                }
                final rate =
                    double.tryParse(_inlineItemRateController.text.trim()) ??
                        0.0;
                setState(() {
                  _items.add(
                    _ManualItem(
                      name: name,
                      quantity: _inlineItemQty,
                      rate: rate,
                      isNew: true,
                    ),
                  );
                  _showInlineNewItem = false;
                  _inlineItemNameController.clear();
                  _inlineItemRateController.clear();
                  _inlineItemQty = 1.0;
                });
                _bumpTotal();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Save',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double get _computedTotal {
    if (_items.isEmpty) return 0.0;
    return _items.fold(0.0, (sum, item) => sum + (item.quantity * item.rate));
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectDeliveryDate() async {
    final defaultDate = DateTime.now().add(const Duration(days: 4));
    final picked = await showDatePicker(
      context: context,
      initialDate: _deliveryDate ?? defaultDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() {
        _deliveryDate = picked;
      });
    }
  }

  Future<void> _submit({bool shareOnWhatsApp = false}) async {
    final partyName = _partySearchController.text.trim();
    if (partyName.isEmpty) {
      AppToast.showError(context, 'Please enter or select a party');
      return;
    }

    final mobile = _mobileController.text.trim();
    if (_partyType == 'customer' && mobile.isNotEmpty && mobile.length != 10) {
      AppToast.showError(
        context,
        'Please enter a valid 10-digit mobile number',
      );
      return;
    }

    final double finalAmount = _items.isEmpty
        ? (double.tryParse(_flatAmountController.text.trim()) ?? 0.0)
        : _computedTotal;

    if (finalAmount <= 0) {
      AppToast.showError(context, 'Amount must be greater than zero');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final earlyShopProfile = ref.read(shopProvider);
      final payload = {
        'party_type': _partyType,
        'party_name': partyName,
        // Also send party_id if a known party was selected — backend uses ID
        // for direct lookup, avoiding any name-mismatch bugs.
        if (_partyType == 'customer' && _selectedCustomer != null)
          'party_id': _selectedCustomer!.id,
        if (_partyType == 'vendor' && _selectedVendor != null)
          'party_id': _selectedVendor!.id,
        if (_partyType == 'customer' &&
            _mobileController.text.trim().isNotEmpty)
          'mobile_number': _mobileController.text.trim(),
        'amount': finalAmount,
        'entry_type': _entryType,
        'payment_mode': _entryType == 'got' ? 'Cash' : _paymentMode,
        if (_paymentMode == 'Credit' && _entryType == 'gave') ...{
          'received_amount':
              double.tryParse(_paidAmountController.text.trim()) ?? 0.0,
        },
        'date': _selectedDate.toUtc().toIsoformat(),
        'notes': _notesController.text.trim(),
        'items': _items.map((it) => it.toJson()).toList(),
        if (earlyShopProfile.shopType == 'laundry') ...{
          'order_date': _selectedDate.toIso8601String().substring(0, 10),
          if (_deliveryDate != null)
            'delivery_date': _deliveryDate!.toIso8601String().substring(0, 10),
        },
      };

      final response = await ApiClient().dio.post(
        '/api/udhar/manual-entry',
        data: payload,
      );

      if (response.data['status'] == 'success') {
        // Extract receipt number assigned by backend
        final String? receiptNum = response.data['receipt_number']?.toString();
        final double? newBalance = response.data['new_balance'] != null
            ? double.tryParse(response.data['new_balance'].toString())
            : null;

        // Trigger data refresh in background — PERF FIX: use fetchLedgersSilent so the
        // heavy sync on /ledgers does NOT block the post-save navigation.
        // PartyDetailPage._loadTransactions() is the authoritative refresh for the detail view.
        unawaited(ref.read(dashboardTotalsProvider.notifier).refresh());
        ref.read(itemCatalogueProvider.notifier).fetchCatalogue();
        if (_partyType == 'customer') {
          unawaited(ref.read(udharProvider.notifier).fetchLedgersSilent());
        } else {
          unawaited(ref.read(vendorLedgerProvider.notifier).fetchLedgers());
        }

        // Extract the ledger id returned by the backend so we can navigate
        // straight into the party's Transaction History.
        final int? ledgerId = response.data['ledger_id'] is int
            ? response.data['ledger_id'] as int
            : int.tryParse(response.data['ledger_id']?.toString() ?? '');

        if (mounted) {
          if (shareOnWhatsApp && _partyType == 'customer') {
              // Ensure shop name is loaded before composing the message.
              await ref.read(shopProvider.notifier).ensureValidShopName();
              final shopProfile = ref.read(shopProvider);
            final double receivedAmount = _entryType == 'got'
                ? finalAmount
                : (_paymentMode == 'Credit'
                      ? (double.tryParse(_paidAmountController.text.trim()) ??
                            0.0)
                      : finalAmount);

            final message = WhatsAppUtils.buildManualBillMessage(
              customerName: partyName,
              shopName: shopProfile.name.isNotEmpty
                  ? shopProfile.name
                  : 'Our Store',
              items: _items
                  .map(
                    (it) => {
                      'name': it.name,
                      'quantity': it.quantity,
                      'rate': it.rate,
                      'unit': it.unit,
                      'amount': it.quantity * it.rate,
                    },
                  )
                  .toList(),
              total: finalAmount,
              paymentMode: _entryType == 'got' ? 'Cash' : _paymentMode,
              receivedAmount: receivedAmount,
              balanceDue: newBalance,
              whatsappCustomNote: shopProfile.whatsappCustomNote,
              orderDate: shopProfile.shopType == 'laundry' ? _selectedDate : null,
              deliveryDate: shopProfile.shopType == 'laundry' ? _deliveryDate : null,
            );

            // Resolve phone: prefer what's typed in the field, then fall
            // back to the customer's stored number.  shareReceipt() will
            // show a single prompt if still empty — no double-dialog.
            String phone = _mobileController.text.trim();
            if (phone.isEmpty) {
              phone = _selectedCustomer?.customerPhone ?? '';
            }
            if (phone.isNotEmpty &&
                !phone.startsWith('+91') &&
                phone.length == 10) {
              phone = '+91$phone';
            }

            if (!mounted) return;
            // Close manual entry sheet
            Navigator.of(context).pop(true);
            // Show WhatsApp share sheet (handles missing phone with one prompt)
            await WhatsAppUtils.shareReceipt(
              context,
              phone: phone,
              message: message,
            );
            // After WhatsApp sheet, open party detail if we have an id AND did not start from detail page
            if (mounted &&
                ledgerId != null &&
                _partyType == 'customer' &&
                widget.initialCustomer == null) {
              _navigateToPartyDetail(ledgerId, partyName);
            }
          } else {
            Navigator.of(context).pop(true);
            final successMsg = receiptNum != null
                ? 'Entry saved! Bill #$receiptNum 🎉'
                : 'Entry added successfully! 🎉';
            AppToast.showSuccess(context, successMsg);
            // Immediately open the party's transaction history if not already inside it
            if (mounted &&
                ledgerId != null &&
                _partyType == 'customer' &&
                widget.initialCustomer == null) {
              _navigateToPartyDetail(ledgerId, partyName);
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Failed to save transaction: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Pushes the Party Detail page for [ledgerId] after a successful save.
  /// Uses a stub CustomerLedger — the detail page fetches fresh data on init.
  void _navigateToPartyDetail(int ledgerId, String partyName) {
    if (!mounted) return;
    // Try to find the real ledger from provider state (may already be updated)
    final ledgers = ref.read(udharProvider).ledgers;
    final match = ledgers.where((l) => l.id == ledgerId).toList();
    final ledger = match.isNotEmpty
        ? match.first
        : CustomerLedger(
            id: ledgerId,
            customerName: partyName,
            balanceDue: 0.0,
          );
    context.push('/party/$ledgerId', extra: ledger);
  }

  /// Builds the mobile number input row.
  /// Tapping it opens the full-screen numpad sheet (dialpad UX).
  Widget _buildMobileNumberFieldNoLabel(BuildContext context) {
    final phoneVal = _mobileController.text;
    final isValid = phoneVal.length == 10;
    final isEmpty = phoneVal.isEmpty;

    return GestureDetector(
      onTap: () => _openNumpad(context),
      child: Container(
        decoration: BoxDecoration(
          color: context.primaryColor.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isValid
                ? context.successColor.withValues(alpha: 0.5)
                : context.primaryColor.withValues(alpha: 0.3),
            width: isValid ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // +91 badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: isValid
                    ? context.successColor.withValues(alpha: 0.1)
                    : context.primaryColor.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  bottomLeft: Radius.circular(15),
                ),
              ),
              child: Text(
                '+91',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: isValid ? context.successColor : context.primaryColor,
                ),
              ),
            ),
            // Number / placeholder
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: isEmpty
                    ? Text(
                        'Tap to enter mobile number',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.textSecondaryColor.withValues(alpha: 0.45),
                        ),
                      )
                    : Text(
                        '${phoneVal.substring(0, phoneVal.length > 5 ? 5 : phoneVal.length)}'
                        '${phoneVal.length > 5 ? ' ${phoneVal.substring(5)}' : ''}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          color: isValid ? context.successColor : context.textColor,
                        ),
                      ),
              ),
            ),
            // Right actions: contact picker + valid check (no phone icon)
            if (ContactUtils.isSupported)
              IconButton(
                icon: Icon(LucideIcons.contact, color: context.primaryColor, size: 20),
                onPressed: () async {
                  final phone = await ContactUtils.pickContactPhone();
                  if (phone != null && mounted) {
                    final d = phone.replaceAll(RegExp(r'[^0-9]'), '');
                    setState(() {
                      _mobileController.text =
                          d.length > 10 ? d.substring(d.length - 10) : d;
                    });
                  }
                },
              )
            else
              const SizedBox(width: 8),
            if (isValid)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(LucideIcons.checkCircle2, color: context.successColor, size: 20),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openNumpad(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PhoneNumpadSheet(
        initial: _mobileController.text,
        title: 'Customer Mobile Number',
      ),
    );
    if (result != null && mounted) {
      setState(() => _mobileController.text = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isGot = _entryType == 'got';
    final Color activeColor = isGot
        ? context.successColor
        : context.primaryColor;
    final bool isCustomer = _partyType == 'customer';
    const Color whatsappGreen = Color(0xFF25D366);
    final Color saveButtonColor = isCustomer ? whatsappGreen : activeColor;

    final customerState = ref.watch(udharProvider);
    final vendorState = ref.watch(vendorLedgerProvider);
    final catalogueState = ref.watch(itemCatalogueProvider);

    final double finalAmount = _items.isEmpty
        ? (double.tryParse(_flatAmountController.text.trim()) ?? 0.0)
        : _computedTotal;

    // Silence unused warning
    final _ = _selectedVendor?.vendorName;

    // Fuzzy-ranked suggestions (customers) / exact match (vendors)
    final query = _partySearchController.text.trim();
    List<dynamic> partySuggestions = [];
    if (_partyType == 'customer') {
      partySuggestions = _fuzzySearchCustomers(query, customerState.ledgers);
    } else {
      final q = query.toLowerCase();
      partySuggestions = vendorState.ledgers
          .where((l) => l.vendorName.toLowerCase().contains(q))
          .toList();
    }

    return Container(
      height: MediaQuery.of(context).size.height,
      decoration: BoxDecoration(
        color: context.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle & Header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Record Manual Entry',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      IconButton(
                        icon: Icon(LucideIcons.x, color: context.textColor),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 20,
                right: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.initialCustomer != null ||
                      widget.initialVendor != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.primaryColor.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: context.primaryColor.withValues(alpha: 0.15),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: context.primaryColor.withValues(
                              alpha: 0.12,
                            ),
                            child: Text(
                              _partyType == 'customer'
                                  ? (_selectedCustomer
                                                ?.customerName
                                                .isNotEmpty ==
                                            true
                                        ? _selectedCustomer!.customerName[0]
                                              .toUpperCase()
                                        : 'C')
                                  : (_selectedVendor?.vendorName.isNotEmpty ==
                                            true
                                        ? _selectedVendor!.vendorName[0]
                                              .toUpperCase()
                                        : 'V'),
                              style: TextStyle(
                                color: context.primaryColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _partyType == 'customer'
                                      ? _selectedCustomer!.customerName
                                      : _selectedVendor!.vendorName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: context.primaryColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _partyType == 'customer'
                                            ? 'Customer'
                                            : 'Supplier',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: context.primaryColor,
                                        ),
                                      ),
                                    ),
                                    if (_partyType == 'customer' &&
                                        _selectedCustomer!.customerPhone !=
                                            null &&
                                        _selectedCustomer!
                                            .customerPhone!
                                            .isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        _selectedCustomer!.customerPhone!,
                                        style: TextStyle(
                                          color: context.textSecondaryColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Party Type Toggle
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: context.borderColor,
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _partyType = 'customer';
                                  _selectedCustomer = null;
                                  _selectedVendor = null;
                                  _partySearchController.clear();
                                  _mobileController.clear();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: _partyType == 'customer'
                                      ? context.primaryColor
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      LucideIcons.user,
                                      size: 16,
                                      color: _partyType == 'customer'
                                          ? Colors.white
                                          : context.textSecondaryColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Customer',
                                      style: TextStyle(
                                        color: _partyType == 'customer'
                                            ? Colors.white
                                            : context.textColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _partyType = 'vendor';
                                  _selectedCustomer = null;
                                  _selectedVendor = null;
                                  _partySearchController.clear();
                                  _mobileController.clear();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: _partyType == 'vendor'
                                      ? context.primaryColor
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      LucideIcons.truck,
                                      size: 16,
                                      color: _partyType == 'vendor'
                                          ? Colors.white
                                          : context.textSecondaryColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Supplier',
                                      style: TextStyle(
                                        color: _partyType == 'vendor'
                                            ? Colors.white
                                            : context.textColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Party Search & Dropdown Stack
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Search field with mic button ──────────────────
                        Stack(
                          children: [
                            TextField(
                              controller: _partySearchController,
                              focusNode: _partySearchFocusNode,
                              style: TextStyle(
                                color: context.textColor,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                labelText: _partyType == 'customer'
                                    ? 'Search Customer'
                                    : 'Search Supplier',
                                hintText: _isListening
                                    ? 'Listening...'
                                    : 'Type name or use voice button →',
                                prefixIcon: Icon(
                                  _isListening
                                      ? LucideIcons.micOff
                                      : LucideIcons.search,
                                  size: 20,
                                  color: _isListening
                                      ? Colors.red
                                      : context.textSecondaryColor,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: _isListening
                                        ? Colors.red.withValues(alpha: 0.6)
                                        : context.borderColor,
                                    width: _isListening ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: _isListening
                                        ? Colors.red
                                        : context.primaryColor,
                                    width: _isListening ? 2 : 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                // Right side: clear OR mic
                                suffixIcon: _partySearchController.text.isNotEmpty && !_isListening
                                    ? IconButton(
                                        icon: const Icon(LucideIcons.x, size: 16),
                                        onPressed: () {
                                          setState(() {
                                            _partySearchController.clear();
                                            _selectedCustomer = null;
                                            _selectedVendor = null;
                                            _mobileController.clear();
                                            _heardText = '';
                                          });
                                        },
                                      )
                                    : _partyType == 'customer' && _speechAvailable
                                        ? GestureDetector(
                                            onTap: _isListening ? _stopListening : _startListening,
                                            child: Padding(
                                              padding: const EdgeInsets.all(10),
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
                                                        : context.primaryColor,
                                                    boxShadow: _isListening
                                                        ? [
                                                            BoxShadow(
                                                              color: Colors.red.withValues(alpha: 0.4),
                                                              blurRadius: 12,
                                                              spreadRadius: 2,
                                                            ),
                                                          ]
                                                        : [],
                                                  ),
                                                  child: Icon(
                                                    _isListening
                                                        ? LucideIcons.micOff
                                                        : LucideIcons.mic,
                                                    size: 18,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          )
                                        : null,
                              ),
                            ),
                          ],
                        ),

                        // ── "I heard: X" banner (shown after voice input) ─
                        if (_heardText.isNotEmpty && !_isListening)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: context.primaryColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: context.primaryColor.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    LucideIcons.volume2,
                                    size: 14,
                                    color: context.primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: context.textSecondaryColor,
                                        ),
                                        children: [
                                          const TextSpan(text: 'I heard: '),
                                          TextSpan(
                                            text: '"$_heardText"',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: context.textColor,
                                            ),
                                          ),
                                          const TextSpan(
                                            text: '  — Select from below or type to refine',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // ── Suggestions dropdown panel ────────────────────
                        if (_showSuggestions)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            constraints: const BoxConstraints(maxHeight: 270),
                            decoration: BoxDecoration(
                              color: context.surfaceColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: context.borderColor,
                                width: 0.5,
                              ),
                              boxShadow: context.premiumShadow,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (partySuggestions.isNotEmpty)
                                  Flexible(
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      // +1 for the "Add as new" row at the bottom
                                      itemCount: partySuggestions.length + 1,
                                      itemBuilder: (ctx, idx) {
                                        // ── "Add as new" button (always last row) ──
                                        if (idx == partySuggestions.length) {
                                          final typedName = _partySearchController.text.trim();
                                          // Check if the typed name exactly matches any suggestion
                                          final bool exactMatchExists = partySuggestions.any((p) {
                                            final name = _partyType == 'customer'
                                                ? (p as CustomerLedger).customerName
                                                : (p as VendorLedger).vendorName;
                                            return name.toLowerCase() == typedName.toLowerCase();
                                          });
                                          // Hide the button if the typed text exactly matches a result
                                          if (exactMatchExists || typedName.isEmpty) {
                                            return const SizedBox.shrink();
                                          }
                                          final partyLabel = _partyType == 'customer'
                                              ? 'customer'
                                              : 'supplier';
                                          return InkWell(
                                            borderRadius: const BorderRadius.vertical(
                                              bottom: Radius.circular(16),
                                            ),
                                            onTap: () {
                                              HapticFeedback.selectionClick();
                                              setState(() {
                                                // Clear any selected party — this will be a brand-new entry
                                                _selectedCustomer = null;
                                                _selectedVendor = null;
                                                _heardText = '';
                                                _showSuggestions = false;
                                              });
                                              _partySearchFocusNode.unfocus();
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 12,
                                              ),
                                              decoration: BoxDecoration(
                                                color: context.primaryColor.withValues(alpha: 0.07),
                                                border: Border(
                                                  top: BorderSide(
                                                    color: context.borderColor,
                                                    width: 0.5,
                                                  ),
                                                ),
                                                borderRadius: const BorderRadius.vertical(
                                                  bottom: Radius.circular(16),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: context.primaryColor.withValues(alpha: 0.12),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      LucideIcons.userPlus,
                                                      size: 15,
                                                      color: context.primaryColor,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: RichText(
                                                      text: TextSpan(
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: context.textColor,
                                                        ),
                                                        children: [
                                                          TextSpan(
                                                            text: 'Add ',
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.w500,
                                                              color: context.textSecondaryColor,
                                                            ),
                                                          ),
                                                          TextSpan(
                                                            text: '"$typedName"',
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.w800,
                                                              color: context.primaryColor,
                                                            ),
                                                          ),
                                                          TextSpan(
                                                            text: ' as new $partyLabel',
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.w500,
                                                              color: context.textSecondaryColor,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  Icon(
                                                    LucideIcons.chevronRight,
                                                    size: 14,
                                                    color: context.primaryColor,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }

                                        // ── Existing suggestion row ──
                                        final p = partySuggestions[idx];
                                        final String name = _partyType == 'customer'
                                            ? (p as CustomerLedger).customerName
                                            : (p as VendorLedger).vendorName;
                                        final double balance = p.balanceDue;
                                        // Show a ✓ match indicator for top result after voice
                                        final bool isTopVoiceMatch =
                                            _heardText.isNotEmpty && idx == 0;

                                        return ListTile(
                                          leading: CircleAvatar(
                                            radius: 16,
                                            backgroundColor: isTopVoiceMatch
                                                ? context.primaryColor.withValues(alpha: 0.18)
                                                : context.primaryColor.withValues(alpha: 0.1),
                                            child: Text(
                                              name.isNotEmpty ? name[0].toUpperCase() : '',
                                              style: TextStyle(
                                                color: context.primaryColor,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          title: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  name,
                                                  style: TextStyle(
                                                    color: context.textColor,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              if (isTopVoiceMatch)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text(
                                                    'Best match',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w700,
                                                      color: Colors.green,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          subtitle: Text(
                                            'Balance: ₹${balance.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              color: context.textSecondaryColor,
                                              fontSize: 12,
                                            ),
                                          ),
                                          onTap: () {
                                            HapticFeedback.selectionClick();
                                            setState(() {
                                              _partySearchController.text = name;
                                              _heardText = '';
                                              if (_partyType == 'customer') {
                                                _selectedCustomer = p as CustomerLedger;
                                                final phone =
                                                    _selectedCustomer?.customerPhone ?? '';
                                                _mobileController.text = phone
                                                    .replaceAll('+91', '')
                                                    .trim();
                                              } else {
                                                _selectedVendor = p as VendorLedger;
                                              }
                                              _showSuggestions = false;
                                            });
                                            _partySearchFocusNode.unfocus();
                                          },
                                        );
                                      },
                                    ),
                                  )
                                else
                                  // No matches — tappable "Add as new" button
                                  InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        _selectedCustomer = null;
                                        _selectedVendor = null;
                                        _heardText = '';
                                        _showSuggestions = false;
                                      });
                                      _partySearchFocusNode.unfocus();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: context.primaryColor.withValues(alpha: 0.12),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              LucideIcons.userPlus,
                                              size: 15,
                                              color: context.primaryColor,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: RichText(
                                              text: TextSpan(
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: context.textColor,
                                                ),
                                                children: [
                                                  TextSpan(
                                                    text: 'Add ',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w500,
                                                      color: context.textSecondaryColor,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: '"${_partySearchController.text.trim()}"',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w800,
                                                      color: context.primaryColor,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: ' as new ${_partyType == 'customer' ? 'customer' : 'supplier'}',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w500,
                                                      color: context.textSecondaryColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Icon(
                                            LucideIcons.chevronRight,
                                            size: 14,
                                            color: context.primaryColor,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (_partyType == 'customer') ...[
                    const SizedBox(height: 20),
                    // Mobile Number + Date chip in one row label
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Mobile number label on left
                        Row(
                          children: [
                            Icon(
                              LucideIcons.smartphone,
                              size: 14,
                              color: context.primaryColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'MOBILE NUMBER',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: context.primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Date pill on right — tappable
                        GestureDetector(
                          onTap: _selectDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: context.primaryColor.withValues(
                                alpha: 0.08,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: context.primaryColor.withValues(
                                  alpha: 0.25,
                                ),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.calendar,
                                  size: 12,
                                  color: context.primaryColor,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _formatDate(_selectedDate),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: context.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildMobileNumberFieldNoLabel(context),
                    // ── Delivery Date row (Laundry shops only) ─────────────
                    Builder(builder: (ctx) {
                      final shopProfile = ref.watch(shopProvider);
                      if (shopProfile.shopType != 'laundry') {
                        return const SizedBox.shrink();
                      }
                      final hasDate = _deliveryDate != null;
                      const deliveryPurple = Color(0xFF7C3AED);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 14),
                          // Label row
                          Row(
                            children: [
                              Icon(
                                LucideIcons.truck,
                                size: 14,
                                color: deliveryPurple,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'DELIVERY DATE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: deliveryPurple,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Full-width tappable delivery date tile — same height as mobile number field
                          GestureDetector(
                            onTap: _selectDeliveryDate,
                            child: Container(
                              decoration: BoxDecoration(
                                color: deliveryPurple.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: hasDate
                                      ? deliveryPurple.withValues(alpha: 0.6)
                                      : deliveryPurple.withValues(alpha: 0.3),
                                  width: hasDate ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Calendar icon badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: hasDate
                                          ? deliveryPurple.withValues(alpha: 0.12)
                                          : deliveryPurple.withValues(alpha: 0.07),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(15),
                                        bottomLeft: Radius.circular(15),
                                      ),
                                    ),
                                    child: Icon(
                                      LucideIcons.calendarClock,
                                      size: 20,
                                      color: deliveryPurple,
                                    ),
                                  ),
                                  // Date text
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14),
                                      child: hasDate
                                          ? Text(
                                              _formatDate(_deliveryDate!),
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.5,
                                                color: deliveryPurple,
                                              ),
                                            )
                                          : Text(
                                              'Tap to pick delivery date',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: deliveryPurple.withValues(alpha: 0.45),
                                              ),
                                            ),
                                    ),
                                  ),
                                  // Check / calendar icon on right
                                  Padding(
                                    padding: const EdgeInsets.only(right: 14),
                                    child: hasDate
                                        ? const Icon(LucideIcons.checkCircle2, color: deliveryPurple, size: 20)
                                        : const Icon(LucideIcons.chevronRight, color: deliveryPurple, size: 20),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ] else ...[
                    // Vendor: show date pill standalone (no mobile field)
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: _selectDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: context.primaryColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: context.primaryColor.withValues(
                                alpha: 0.25,
                              ),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.calendar,
                                size: 12,
                                color: context.primaryColor,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _formatDate(_selectedDate),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: context.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Items List Header & Flat Amount input
                  if (_items.isEmpty) ...[
                    // Show a simple amount field if no line items are added yet
                    TextFormField(
                      controller: _flatAmountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Transaction Amount (₹)',
                        hintText: '0.00',
                        prefixIcon: const Icon(
                          LucideIcons.indianRupee,
                          size: 20,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: context.borderColor),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: context.primaryColor),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // ── New Item button + inline form ─────────────────────────
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showInlineNewItem = !_showInlineNewItem;
                          if (_showInlineNewItem) {
                            _inlineItemNameController.clear();
                            _inlineItemRateController.clear();
                            _inlineItemQty = 1.0;
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: context.primaryColor.withValues(alpha: 0.08),
                          border: Border.all(
                            color: context.primaryColor.withValues(alpha: 0.4),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showInlineNewItem ? LucideIcons.x : LucideIcons.plus,
                              size: 15,
                              color: context.primaryColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _showInlineNewItem ? 'Cancel' : 'New Item',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showInlineNewItem) _buildInlineNewItemForm(context),
                  ] else ...[
                    // ── Items header row with Add buttons ──────────────
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Text(
                            'Line Items',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.textSecondaryColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const Spacer(),
                          // Add item manually
                          GestureDetector(
                            onTap: _openQuickBill,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: context.primaryColor.withValues(alpha: 0.08),
                                border: Border.all(
                                  color: context.primaryColor.withValues(alpha: 0.4),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.plus,
                                    size: 14,
                                    color: context.primaryColor,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Add Item',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: context.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Listening indicator banner
                    if (_isItemListening)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5722).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFF5722).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              LucideIcons.mic,
                              size: 16,
                              color: Color(0xFFFF5722),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Listening... say items like: "2 kg atta, 5 litre oil, 3 soap"',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFFF5722),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: _stopItemListening,
                              child: const Icon(
                                LucideIcons.x,
                                size: 16,
                                color: Color(0xFFFF5722),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Line Items builder using spacious card design
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _items.length,
                      itemBuilder: (ctx, idx) {
                        final item = _items[idx];
                        // NEW item highlight: amber border if added via voice and not in catalogue
                        final cardBorderColor = item.isNew
                            ? const Color(0xFFFFC107).withValues(alpha: 0.8)
                            : context.borderColor.withValues(alpha: 0.6);
                        final cardBgColor = item.isNew
                            ? const Color(0xFFFFC107).withValues(alpha: 0.05)
                            : context.surfaceColor;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12.0),
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: cardBorderColor,
                              width: item.isNew ? 1.5 : 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // NEW badge for voice-added items not in catalogue
                              if (item.isNew)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFC107).withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: const Color(0xFFFFC107),
                                            width: 1,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              LucideIcons.sparkles,
                                              size: 11,
                                              color: Color(0xFFE65100),
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'NEW ITEM — set price',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFFE65100),
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              // Row 1: Item Search / Input & Delete button
                              Row(
                                children: [
                                  Expanded(
                                    child: Autocomplete<CatalogueItem>(
                                      displayStringForOption: (option) =>
                                          option.itemName,
                                      initialValue: TextEditingValue(
                                        text: item.name,
                                      ),
                                      optionsBuilder:
                                          (TextEditingValue textEditingValue) {
                                            if (textEditingValue.text.isEmpty) {
                                              return const Iterable<
                                                CatalogueItem
                                              >.empty();
                                            }
                                            return catalogueState.items.where((
                                              CatalogueItem option,
                                            ) {
                                              return option.itemName
                                                  .toLowerCase()
                                                  .contains(
                                                    textEditingValue.text
                                                        .toLowerCase(),
                                                  );
                                            });
                                          },
                                      onSelected: (CatalogueItem selection) {
                                        setState(() {
                                          item.name = selection.itemName;
                                          item.rate = selection.lastPrice;
                                          item.unit = selection.unit;
                                          item.rateController.text = selection
                                              .lastPrice
                                              .toStringAsFixed(0);
                                        });
                                        _bumpTotal();
                                        // Auto-focus rate field on selection
                                        item.rateFocusNode.requestFocus();
                                      },
                                      fieldViewBuilder:
                                          (
                                            context,
                                            textController,
                                            focusNode,
                                            onFieldSubmitted,
                                          ) {
                                            // Keep item.name in sync if the user types manually
                                            textController.addListener(() {
                                              item.name = textController.text;
                                            });

                                            return TextFormField(
                                              controller: textController,
                                              focusNode: focusNode,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              decoration: InputDecoration(
                                                labelText: 'Item Name',
                                                labelStyle: TextStyle(
                                                  fontSize: 12,
                                                  color: context.textSecondaryColor,
                                                ),
                                                hintText: 'Search or enter item...',
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 12,
                                                    ),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            context.borderColor,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color: context
                                                            .primaryColor,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                              ),
                                              onFieldSubmitted: (val) {
                                                onFieldSubmitted();
                                              },
                                            );
                                          },
                                      optionsViewBuilder: (context, onSelected, options) {
                                        return Align(
                                          alignment: Alignment.topLeft,
                                          child: Material(
                                            elevation: 8,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            shadowColor: Colors.black
                                                .withValues(alpha: 0.15),
                                            color: context.surfaceColor,
                                            child: Container(
                                              width: MediaQuery.of(context).size.width - 100,
                                              constraints: const BoxConstraints(
                                                maxHeight: 200,
                                              ),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: context.borderColor
                                                      .withValues(alpha: 0.5),
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: ListView.separated(
                                                  padding: EdgeInsets.zero,
                                                  shrinkWrap: true,
                                                  itemCount: options.length,
                                                  separatorBuilder:
                                                      (context, i) => Divider(
                                                        height: 1,
                                                        color: context
                                                            .borderColor
                                                            .withValues(
                                                              alpha: 0.5,
                                                            ),
                                                      ),
                                                  itemBuilder: (BuildContext context, int index) {
                                                    final CatalogueItem option =
                                                        options.elementAt(
                                                          index,
                                                        );
                                                    return InkWell(
                                                      onTap: () =>
                                                          onSelected(option),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 12,
                                                              vertical: 12,
                                                            ),
                                                        child: Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                option.itemName,
                                                                style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 14,
                                                                ),
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                            ),
                                                            Text(
                                                              '₹${option.lastPrice.toStringAsFixed(0)}',
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: context
                                                                    .primaryColor,
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
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(
                                      LucideIcons.trash2,
                                      color: context.errorColor.withValues(alpha: 0.8),
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      setState(() {
                                        final removed = _items.removeAt(idx);
                                        removed.dispose();
                                      });
                                      _bumpTotal();
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Row 2: Qty | Rate (₹) | Amount — fixed widths via LayoutBuilder
                              LayoutBuilder(
                                builder: (ctx2, constraints) {
                                  const amountWidth = 68.0;
                                  const spacing = 8.0;
                                  final remaining = constraints.maxWidth - amountWidth - spacing * 2;
                                  final qtyWidth = remaining * 0.44;
                                  final rateWidth = remaining * 0.56;
                                  final rowSubtotal = item.quantity * item.rate;
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // ── Qty ─────────────────────────────────────────
                                      SizedBox(
                                        width: qtyWidth,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Qty',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: ctx2.textSecondaryColor,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            EditableQtyStepper(
                                              qty: item.quantity,
                                              btnSize: 36.0,
                                              boxWidth: (qtyWidth - 72).clamp(30.0, 56.0),
                                              boxHeight: 44.0,
                                              isDecimal: item.unit == 'KG' ||
                                                  item.unit == 'LITRE' ||
                                                  item.unit == 'L',
                                              showTrashAtOne: true,
                                              itemName: item.name.isEmpty
                                                  ? 'Manual Entry Item'
                                                  : item.name,
                                              rate: item.rate,
                                              unit: item.unit,
                                              onChanged: (newQty) {
                                                setState(() {
                                                  item.quantity = newQty.toDouble();
                                                });
                                                _bumpTotal();
                                              },
                                              onDecrement: () {
                                                HapticFeedback.lightImpact();
                                                setState(() {
                                                  if (item.quantity > 1.0) {
                                                    final step = (item.unit == 'KG' ||
                                                            item.unit == 'LITRE' ||
                                                            item.unit == 'L')
                                                        ? 0.5
                                                        : 1.0;
                                                    item.quantity -= step;
                                                  } else {
                                                    final removed = _items.removeAt(idx);
                                                    removed.dispose();
                                                  }
                                                });
                                                _bumpTotal();
                                              },
                                              onIncrement: () {
                                                HapticFeedback.lightImpact();
                                                setState(() {
                                                  final step = (item.unit == 'KG' ||
                                                          item.unit == 'LITRE' ||
                                                          item.unit == 'L')
                                                      ? 0.5
                                                      : 1.0;
                                                  item.quantity += step;
                                                });
                                                _bumpTotal();
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: spacing),
                                      // ── Rate (₹) ────────────────────────────────────
                                      SizedBox(
                                        width: rateWidth,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Rate (₹)',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: ctx2.textSecondaryColor,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            SizedBox(
                                              height: 44,
                                              child: TextFormField(
                                                controller: item.rateController,
                                                focusNode: item.rateFocusNode,
                                                keyboardType:
                                                    const TextInputType.numberWithOptions(
                                                      decimal: true,
                                                    ),
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                                decoration: InputDecoration(
                                                  prefixText: '₹',
                                                  hintText: '0',
                                                  contentPadding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 10,
                                                      ),
                                                  enabledBorder: OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                        color: ctx2.borderColor),
                                                    borderRadius:
                                                        BorderRadius.circular(12),
                                                  ),
                                                  focusedBorder: OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                        color: ctx2.primaryColor),
                                                    borderRadius:
                                                        BorderRadius.circular(12),
                                                  ),
                                                ),
                                                onChanged: (val) {
                                                  setState(() {
                                                    item.rate =
                                                        double.tryParse(val) ?? 0.0;
                                                  });
                                                  _bumpTotal();
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: spacing),
                                      // ── Amount ──────────────────────────────────────
                                      SizedBox(
                                        width: amountWidth,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                           children: [
                                             Text(
                                               'Amount',
                                               style: TextStyle(
                                                 fontSize: 11,
                                                 fontWeight: FontWeight.w700,
                                                 color: ctx2.textSecondaryColor,
                                               ),
                                             ),
                                             const SizedBox(height: 4),
                                             Container(
                                               height: 44,
                                               alignment: Alignment.centerRight,
                                               child: AnimatedSwitcher(
                                                 duration: const Duration(milliseconds: 200),
                                                 transitionBuilder: (child, animation) =>
                                                     FadeTransition(
                                                       opacity: animation,
                                                       child: SlideTransition(
                                                         position: Tween<Offset>(
                                                           begin: const Offset(0, -0.3),
                                                           end: Offset.zero,
                                                         ).animate(animation),
                                                         child: child,
                                                       ),
                                                     ),
                                                 child: Text(
                                                   key: ValueKey('sub_${idx}_${rowSubtotal.toInt()}'),
                                                   rowSubtotal > 0
                                                       ? '₹${rowSubtotal.toStringAsFixed(0)}'
                                                       : '—',
                                                   style: TextStyle(
                                                     fontSize: 13,
                                                     fontWeight: FontWeight.w900,
                                                     color: rowSubtotal > 0
                                                         ? ctx2.primaryColor
                                                         : ctx2.textSecondaryColor,
                                                   ),
                                                 ),
                                               ),
                                             ),
                                           ],
                                         ),
                                       ),
                                     ],
                                   );
                                 },
                               ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    // ── New Item button + inline form (below existing items) ──
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showInlineNewItem = !_showInlineNewItem;
                          if (_showInlineNewItem) {
                            _inlineItemNameController.clear();
                            _inlineItemRateController.clear();
                            _inlineItemQty = 1.0;
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: context.primaryColor.withValues(alpha: 0.08),
                          border: Border.all(
                            color: context.primaryColor.withValues(alpha: 0.4),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showInlineNewItem ? LucideIcons.x : LucideIcons.plus,
                              size: 14,
                              color: context.primaryColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _showInlineNewItem ? 'Cancel' : 'New Item',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showInlineNewItem) _buildInlineNewItemForm(context),
                  ],
                  const SizedBox(height: 20),

                  // For vendors: keep simple YOU GOT / YOU GAVE in body
                  if (_partyType == 'vendor') ...[
                    Row(
                      children: [
                        Expanded(
                          child: _EntryTypeButton(
                            label: 'YOU GOT',
                            isSelected: _entryType == 'got',
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _entryType = 'got');
                            },
                            activeColor: context.successColor,
                            icon: LucideIcons.arrowDownLeft,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _EntryTypeButton(
                            label: 'YOU GAVE',
                            isSelected: _entryType == 'gave',
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _entryType = 'gave');
                            },
                            activeColor: context.errorColor,
                            icon: LucideIcons.arrowUpRight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Notes (Optional)
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Notes (Optional)',
                      hintText: 'Add bill details, context, etc.',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ── STICKY BOTTOM PANEL ──────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: context.backgroundColor,
              border: Border(
                top: BorderSide(
                  color: context.borderColor.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Customer-only: Transaction type + totals in bottom panel ──
                    if (_partyType == 'customer') ...[
                      // Row 1: Total Bill | Paid Now | Balance Due
                      Builder(
                        builder: (ctx) {
                          final total = _items.isEmpty
                              ? (double.tryParse(
                                      _flatAmountController.text.trim(),
                                    ) ??
                                    0.0)
                              : _computedTotal;
                          final balanceVal =
                              _entryType == 'gave' && _paymentMode == 'Credit'
                              ? (total -
                                        (double.tryParse(
                                              _paidAmountController.text.trim(),
                                            ) ??
                                            0.0))
                                    .clamp(0.0, double.infinity)
                              : (_entryType == 'got' ? 0.0 : 0.0);

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Total Bill
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Bill',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: context.textSecondaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  ScaleTransition(
                                    scale: _totalBumpAnimation,
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      child: Text(
                                        '₹${total.toStringAsFixed(0)}',
                                        key: ValueKey(total.toInt()),
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          color: activeColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              // Pencil icon to edit total (only when no items)
                              if (_items.isEmpty)
                                Icon(
                                  LucideIcons.pencil,
                                  size: 13,
                                  color: context.textSecondaryColor,
                                ),
                              const Spacer(),
                              // Paid Now field (only for Credit sale)
                              if (_entryType == 'gave' &&
                                  _paymentMode == 'Credit') ...[
                                SizedBox(
                                  width: 100,
                                  child: TextField(
                                    controller: _paidAmountController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                    onChanged: (_) => setState(() {}),
                                    decoration: InputDecoration(
                                      labelText: 'Amount Paid',
                                      labelStyle: TextStyle(
                                        fontSize: 9,
                                        color: context.textSecondaryColor,
                                      ),
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 8,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: context.borderColor,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: context.primaryColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Balance Due
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Bal.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: context.textSecondaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      '₹${balanceVal.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: balanceVal > 0
                                            ? context.errorColor
                                            : context.successColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                // Item count badge for non-credit modes
                                if (_items.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: activeColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${_items.length} item${_items.length == 1 ? '' : 's'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: activeColor,
                                      ),
                                    ),
                                  ),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      // Row 2: Cash | Credit | UPI  +  Payment Received
                      Row(
                        children: [
                          // Cash button
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _entryType = 'gave';
                                  _paymentMode = 'Cash';
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (_entryType == 'gave' &&
                                          _paymentMode == 'Cash')
                                      ? context.primaryColor
                                      : context.surfaceColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color:
                                        (_entryType == 'gave' &&
                                            _paymentMode == 'Cash')
                                        ? context.primaryColor
                                        : context.borderColor,
                                  ),
                                ),
                                child: Text(
                                  'Cash',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color:
                                        (_entryType == 'gave' &&
                                            _paymentMode == 'Cash')
                                        ? Colors.white
                                        : context.textColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Credit button
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _entryType = 'gave';
                                  _paymentMode = 'Credit';
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (_entryType == 'gave' &&
                                          _paymentMode == 'Credit')
                                      ? context.primaryColor
                                      : context.surfaceColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color:
                                        (_entryType == 'gave' &&
                                            _paymentMode == 'Credit')
                                        ? context.primaryColor
                                        : context.borderColor,
                                  ),
                                ),
                                child: Text(
                                  'Credit',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color:
                                        (_entryType == 'gave' &&
                                            _paymentMode == 'Credit')
                                        ? Colors.white
                                        : context.textColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ] else ...[
                      // Vendor: just show total row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (_items.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: activeColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_items.length} item${_items.length == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: activeColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          const Spacer(),
                          Text(
                            'TOTAL',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: context.textSecondaryColor,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(width: 12),
                          ScaleTransition(
                            scale: _totalBumpAnimation,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              transitionBuilder: (child, anim) =>
                                  SlideTransition(
                                    position:
                                        Tween<Offset>(
                                          begin: const Offset(0, 0.5),
                                          end: Offset.zero,
                                        ).animate(
                                          CurvedAnimation(
                                            parent: anim,
                                            curve: Curves.easeOut,
                                          ),
                                        ),
                                    child: FadeTransition(
                                      opacity: anim,
                                      child: child,
                                    ),
                                  ),
                              child: Text(
                                '₹${finalAmount.toStringAsFixed(0)}',
                                key: ValueKey(finalAmount.toInt()),
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: activeColor,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    // Action buttons
                    Row(
                      children: [
                        // Save Only
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : () => _submit(),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: activeColor, width: 2),
                              foregroundColor: activeColor,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: activeColor,
                                    ),
                                  )
                                : const Text(
                                    'SAVE',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Save + Send on WhatsApp
                        Expanded(
                          flex: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: LinearGradient(
                                colors: [
                                  saveButtonColor,
                                  saveButtonColor.withValues(alpha: 0.82),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: saveButtonColor.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : () => _submit(shareOnWhatsApp: true),
                              icon: isCustomer
                                  ? const FaIcon(
                                      FontAwesomeIcons.whatsapp,
                                      size: 16,
                                    )
                                  : const Icon(LucideIcons.check, size: 16),
                              label: Text(
                                isCustomer ? 'SAVE + WHATSAPP' : 'SAVE',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final comparison = DateTime(date.year, date.month, date.day);

    if (comparison == today) {
      return 'Today, ${date.day} ${_monthName(date.month)}';
    } else if (comparison == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, ${date.day} ${_monthName(date.month)}';
    } else {
      return '${date.day} ${_monthName(date.month)}, ${date.year}';
    }
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}

extension _DateTimeIso on DateTime {
  String toIsoformat() {
    return toIso8601String();
  }
}

class _EntryTypeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color activeColor;
  final IconData icon;

  const _EntryTypeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.activeColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.08)
              : context.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? activeColor
                : context.borderColor.withValues(alpha: 0.5),
            width: isSelected ? 2.5 : 1.5,
          ),
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    activeColor.withValues(alpha: 0.12),
                    activeColor.withValues(alpha: 0.02),
                  ],
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withValues(alpha: 0.1)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? activeColor : context.textSecondaryColor,
                size: 20,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : context.textSecondaryColor,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
