// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Marathi (`mr`).
class AppLocalizationsMr extends AppLocalizations {
  AppLocalizationsMr([String locale = 'mr']) : super(locale);

  @override
  String get appTitle => 'SnapKhata';

  @override
  String get dashboardTitle => 'होम';

  @override
  String welcomeBack(String userName) {
    return 'नमस्कार, $userName';
  }

  @override
  String get quickActions => 'जलद क्रिया';

  @override
  String get reviewSync => 'बिल चेक करा';

  @override
  String get unmappedItems => 'नवीन माल';

  @override
  String get outOfStock => 'स्टॉक संपला';

  @override
  String get totalSales => 'एकूण विक्री';

  @override
  String get processNow => 'आता तपासा';

  @override
  String get mapItems => 'आयटम जोडा';

  @override
  String get restockList => 'माल भरा';

  @override
  String get language => 'भाषा';

  @override
  String get selectLanguage => 'भाषा निवडा';

  @override
  String get settings => 'सेटिंग्ज';

  @override
  String get preferences => 'प्राधान्ये';

  @override
  String get shopDetails => 'दुकान माहिती';

  @override
  String get darkMode => 'डार्क मोड';

  @override
  String get ordersProcessed => 'ऑर्डर्स';

  @override
  String get account => 'खाते';

  @override
  String get logOut => 'लॉग आउट';

  @override
  String get about => 'आमच्याबद्दल';

  @override
  String get partiesKhata => 'खाते';

  @override
  String get toCollect => 'येणे बाकी';

  @override
  String get toGive => 'देणे बाकी';

  @override
  String get scanBill => 'बिल स्कॅन करा';
}
