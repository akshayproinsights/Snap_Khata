// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Telugu (`te`).
class AppLocalizationsTe extends AppLocalizations {
  AppLocalizationsTe([String locale = 'te']) : super(locale);

  @override
  String get appTitle => 'డిజీఎంట్రీ';

  @override
  String get dashboardTitle => 'డాష్‌బోర్డ్';

  @override
  String welcomeBack(String userName) {
    return 'తిరిగి స్వాగతం, $userName';
  }

  @override
  String get quickActions => 'త్వరిత చర్యలు';

  @override
  String get reviewSync => 'సమీక్ష మరియు సమకాలీకరణ';

  @override
  String get unmappedItems => 'మ్యాప్ చేయని అంశాలు';

  @override
  String get outOfStock => 'స్టాక్ లేదు';

  @override
  String get totalSales => 'మొత్తం విక్రయాలు';

  @override
  String get processNow => 'ఇప్పుడే ప్రాసెస్ చేయండి';

  @override
  String get mapItems => 'లింక్ ఐటెమ్స్';

  @override
  String get restockList => 'రీస్టాక్ జాబితా';

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
