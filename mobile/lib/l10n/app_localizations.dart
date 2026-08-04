import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_mr.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_te.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('mr'),
    Locale('ta'),
    Locale('te'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'SnapKhata'**
  String get appTitle;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'HOME'**
  String get dashboardTitle;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back, {userName}'**
  String welcomeBack(String userName);

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @reviewSync.
  ///
  /// In en, this message translates to:
  /// **'REVIEW & SYNC'**
  String get reviewSync;

  /// No description provided for @unmappedItems.
  ///
  /// In en, this message translates to:
  /// **'UNMAPPED ITEMS'**
  String get unmappedItems;

  /// No description provided for @outOfStock.
  ///
  /// In en, this message translates to:
  /// **'OUT OF STOCK'**
  String get outOfStock;

  /// No description provided for @totalSales.
  ///
  /// In en, this message translates to:
  /// **'TOTAL SALES'**
  String get totalSales;

  /// No description provided for @processNow.
  ///
  /// In en, this message translates to:
  /// **'Process Now'**
  String get processNow;

  /// No description provided for @mapItems.
  ///
  /// In en, this message translates to:
  /// **'Link Items'**
  String get mapItems;

  /// No description provided for @restockList.
  ///
  /// In en, this message translates to:
  /// **'Restock List'**
  String get restockList;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'SETTINGS'**
  String get settings;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @shopDetails.
  ///
  /// In en, this message translates to:
  /// **'Shop Details'**
  String get shopDetails;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @ordersProcessed.
  ///
  /// In en, this message translates to:
  /// **'Orders Processed'**
  String get ordersProcessed;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @partiesKhata.
  ///
  /// In en, this message translates to:
  /// **'PARTIES'**
  String get partiesKhata;

  /// No description provided for @toCollect.
  ///
  /// In en, this message translates to:
  /// **'TO COLLECT'**
  String get toCollect;

  /// No description provided for @toGive.
  ///
  /// In en, this message translates to:
  /// **'TO GIVE'**
  String get toGive;

  /// No description provided for @scanBill.
  ///
  /// In en, this message translates to:
  /// **'SCAN BILL'**
  String get scanBill;

  // ─── Extended strings (not generated by l10n tool; added manually) ─────────

  String get save => 'Save';
  String get cancel => 'Cancel';
  String get deleteAction => 'Delete';
  String get confirm => 'Confirm';
  String get retry => 'Retry';
  String get search => 'Search...';
  String get searchCustomersVendors => 'Search customers or vendors...';
  String get noPartiesFound => 'No parties found';
  String get addCustomerOrSupplier => 'Add customers or suppliers to track Khata.';
  String get allParties => 'All';
  String get pendingParties => 'Pending';
  String get customers => 'Customers';
  String get suppliers => 'Suppliers';
  String get gallaCounter => 'Dashboard';
  String get deleteParties => 'Delete Parties';
  String deletePartiesConfirm(int count) => 'Are you sure you want to delete $count parties?';
  String get selected => 'Selected';
  String get total => 'TOTAL';
  String get goodMorning => 'Good morning,';
  String get goodAfternoon => 'Good afternoon,';
  String get goodEvening => 'Good evening,';
  String get reviewPendingInvoices => 'Review pending invoices';
  String get syncInProgress => 'Sync in progress...';
  String get orderDetails => 'Order Details';
  String get totalBillAmount => 'Total Bill Amount';
  String get balanceDue => 'Balance Due';
  String get paymentType => 'Payment Type';
  String get totalAmount => 'Total Amount';
  String get receiptNumber => 'Receipt Number';
  String get date => 'Date';
  String get customerDetails => 'Customer Details';
  String get customerName => 'Customer Name';
  String get mobileNumber => 'Mobile Number';
  String get orderedItems => 'Ordered Items';
  String get noItemsFound => 'No items found';
  String get orderSummary => 'Order Summary';
  String get paymentRecorded => 'Payment recorded! 🎉';
  String get failedToSavePayment => 'Failed to save payment.';
  String get transactionDeleted => 'Transaction deleted successfully';
  String get failedToDeleteTransaction => 'Failed to delete transaction';
  String get transactionAdded => 'Transaction added';
  String get couldNotFindOrder => 'Could not find order details.';
  String get shopName => 'Shop Name';
  String get completeAddress => 'Complete Address';
  String get phoneNumber => 'Phone Number';
  String get gstinOptional => 'GSTIN (Optional)';
  String get upiIdOptional => 'UPI ID (Optional)';
  String get upiQrNote => 'UPI ID is shown as Scan-to-Pay QR on your invoice';
  String get shopLogo => 'Shop Logo';
  String get chooseFromGallery => 'Choose from Gallery';
  String get takeAPhoto => 'Take a Photo';
  String get removeLogo => 'Remove logo';
  String get termsAndConditions => 'Terms & Conditions on Invoice';
  String get whatsappNote => 'WhatsApp Bill/Reminder Note';
  String get shopType => 'Shop Type';
  String get preview => 'PREVIEW';
  String get saveAndSync => 'Save & Sync';
  String get shopDetailsSaved => 'Shop details saved & synced';
  String get autofillFromReceipt => 'Autofill from Receipt / Card (AI Scan)';
  String get aiExtractingDetails => 'AI extracting shop details...';
  String get autofillSuccess => 'Autofilled successfully! Please review & save.';
  String get failedToExtract => 'Failed to extract receipt';
  String get scanReceiptCard => 'Scan Receipt / Business Card';
  String get chooseLogoSource => 'Choose Logo Source';
  String get failedToUploadLogo => 'Failed to upload logo';
  String get myItemCatalogue => 'My Item Catalogue';
  String get manageItemsAndPrices => 'Manage items and prices';
  String get dashboardAnalytics => 'Dashboard Analytics';
  String get viewSalesAndPurchases => 'View sales and purchases';
  String get viewUsageMetrics => 'View real usage metrics';
  String get versionInfo => 'Version 1.0.0 · Built for Indian SMBs';
  String get syncing => 'Syncing...';
  String get shopDetailsInfo => 'This info appears on your invoices & syncs across devices';
  String get deleteOrder => 'Delete Order Record?';
  String get orderDeleted => 'Order deleted successfully.';
  String get couldNotGenerateLink => 'Could not generate secure receipt link. Please try again.';
  String get advancedFilters => 'Advanced Filters';
  String get clearAll => 'Clear All';
  String get clearFilters => 'Clear Filters';
  String get noInvoicesFound => 'No Invoices Found';
  String get adjustFilters => 'Adjust your filters or sync new invoices.';
  String get groupViewBy => 'GROUP VIEW BY';
  String get deleteSelected => 'Delete Selected';
  String get selectAll => 'Select All';
  String get totalReceipts => 'TOTAL RECEIPTS';
  String get totalAmountLabel => 'TOTAL AMOUNT';
  String get deleteSelectedConfirm => 'Delete Selected?';
  String get includedInItemPrices => 'INCLUDED IN ITEM PRICES';
  String get saveTransaction => 'Save Transaction';
  String get outLabel => 'OUT';
  String get inLabel => 'IN';
  String get uploadInvoices => 'Upload Invoices';
  String get scanPhotoOrSelect => 'Scan, photo, or select files';
  String get clear => 'Clear';
  String get partiesKhataTitle => 'PARTIES';
  String get dashboard => 'Dashboard';
  String get tapToSetUp => 'Tap to set up';
  String get addFirstItem => 'Add First Item';
  String get done => 'Done';
  String get edit => 'Edit';
  String get remove => 'Remove';
  String get noDataAvailable => 'No data available';
  String get errorLabel => 'Error';
  String get noDataForPeriod => 'No data for this period';
  String get failedToLoadImage => 'Failed to load receipt image.';
  String get noCreditBookEntry => 'No credit book entry found for this customer yet.';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi', 'mr', 'ta', 'te'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'mr':
      return AppLocalizationsMr();
    case 'ta':
      return AppLocalizationsTa();
    case 'te':
      return AppLocalizationsTe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
