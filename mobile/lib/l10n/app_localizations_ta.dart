// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tamil (`ta`).
class AppLocalizationsTa extends AppLocalizations {
  AppLocalizationsTa([String locale = 'ta']) : super(locale);

  @override
  String get appTitle => 'டிஜிஎன்ட்ரி';

  @override
  String get dashboardTitle => 'டாஷ்போர்டு';

  @override
  String welcomeBack(String userName) {
    return 'மீண்டும் வருக, $userName';
  }

  @override
  String get quickActions => 'விரைவான செயல்கள்';

  @override
  String get reviewSync => 'மதிப்பாய்வு & ஒத்திசைவு';

  @override
  String get unmappedItems => 'வரைபடமாக்கப்படாத உருப்படிகள்';

  @override
  String get outOfStock => 'கையிருப்பு இல்லை';

  @override
  String get totalSales => 'மொத்த விற்பனை';

  @override
  String get processNow => 'இப்போது செயல்படுத்து';

  @override
  String get mapItems => 'உருப்படிகளை வரைபடமாக்கு';

  @override
  String get restockList => 'மறுசீரமைப்பு பட்டியல்';
}
