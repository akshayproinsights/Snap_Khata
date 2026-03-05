// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'डिजीएंट्री';

  @override
  String get dashboardTitle => 'डैशबोर्ड';

  @override
  String welcomeBack(String userName) {
    return 'वापसी पर स्वागत है, $userName';
  }

  @override
  String get quickActions => 'त्वरित क्रियाएं';

  @override
  String get reviewSync => 'समीक्षा और सिंक करें';

  @override
  String get unmappedItems => 'अनमैप किए गए आइटम';

  @override
  String get outOfStock => 'स्टॉक से बाहर';

  @override
  String get totalSales => 'कुल बिक्री';

  @override
  String get processNow => 'अभी प्रोसेस करें';

  @override
  String get mapItems => 'मैप आइटम';

  @override
  String get restockList => 'रेस्टॉक सूची';
}
