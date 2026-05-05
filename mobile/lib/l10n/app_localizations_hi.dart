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
  String get mapItems => 'लिंक आइटम';

  @override
  String get restockList => 'रेस्टॉक सूची';

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get settings => 'SETTINGS';

  @override
  String get preferences => 'Preferences';

  @override
  String get shopDetails => 'Shop Details';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get ordersProcessed => 'Orders Processed';

  @override
  String get account => 'Account';

  @override
  String get logOut => 'Log Out';

  @override
  String get about => 'About';

  @override
  String get partiesKhata => 'PARTIES';

  @override
  String get toCollect => 'TO COLLECT';

  @override
  String get toGive => 'TO GIVE';

  @override
  String get scanBill => 'SCAN BILL';
}
