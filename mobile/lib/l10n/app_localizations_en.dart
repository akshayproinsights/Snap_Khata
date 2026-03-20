// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'SnapKhata';

  @override
  String get dashboardTitle => 'HOME';

  @override
  String welcomeBack(String userName) {
    return 'Welcome back, $userName';
  }

  @override
  String get quickActions => 'Quick Actions';

  @override
  String get reviewSync => 'REVIEW & SYNC';

  @override
  String get unmappedItems => 'UNMAPPED ITEMS';

  @override
  String get outOfStock => 'OUT OF STOCK';

  @override
  String get totalSales => 'TOTAL SALES';

  @override
  String get processNow => 'Process Now';

  @override
  String get mapItems => 'Link Items';

  @override
  String get restockList => 'Restock List';
}
