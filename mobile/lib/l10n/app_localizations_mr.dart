// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Marathi (`mr`).
class AppLocalizationsMr extends AppLocalizations {
  AppLocalizationsMr([String locale = 'mr']) : super(locale);

  @override
  String get appTitle => 'डिजीएंट्री';

  @override
  String get dashboardTitle => 'डॅशबोर्ड';

  @override
  String welcomeBack(String userName) {
    return 'परत आल्याबद्दल स्वागत आहे, $userName';
  }

  @override
  String get quickActions => 'त्वरित क्रिया';

  @override
  String get reviewSync => 'पुनरावलोकन आणि सिंक';

  @override
  String get unmappedItems => 'मॅप न केलेले आयटम';

  @override
  String get outOfStock => 'स्टॉकमध्ये नाही';

  @override
  String get totalSales => 'एकूण विक्री';

  @override
  String get processNow => 'आता प्रक्रिया करा';

  @override
  String get mapItems => 'आयटम मॅप करा';

  @override
  String get restockList => 'रेस्टॉक सूची';
}
