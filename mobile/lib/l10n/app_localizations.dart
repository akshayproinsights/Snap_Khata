import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_mr.dart';

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
    Locale('mr'),
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

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @deleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAction;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get search;

  /// No description provided for @searchCustomersVendors.
  ///
  /// In en, this message translates to:
  /// **'Search customers or vendors...'**
  String get searchCustomersVendors;

  /// No description provided for @noPartiesFound.
  ///
  /// In en, this message translates to:
  /// **'No parties found'**
  String get noPartiesFound;

  /// No description provided for @addCustomerOrSupplier.
  ///
  /// In en, this message translates to:
  /// **'Add customers or suppliers to track Khata.'**
  String get addCustomerOrSupplier;

  /// No description provided for @allParties.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allParties;

  /// No description provided for @pendingParties.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pendingParties;

  /// No description provided for @customers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customers;

  /// No description provided for @suppliers.
  ///
  /// In en, this message translates to:
  /// **'Suppliers'**
  String get suppliers;

  /// No description provided for @gallaCounter.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get gallaCounter;

  /// No description provided for @deleteParties.
  ///
  /// In en, this message translates to:
  /// **'Delete Parties'**
  String get deleteParties;

  /// No description provided for @deletePartiesConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {count} parties?'**
  String deletePartiesConfirm(int count);

  /// No description provided for @selected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get selected;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'TOTAL'**
  String get total;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning,'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon,'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening,'**
  String get goodEvening;

  /// No description provided for @reviewPendingInvoices.
  ///
  /// In en, this message translates to:
  /// **'Review pending invoices'**
  String get reviewPendingInvoices;

  /// No description provided for @syncInProgress.
  ///
  /// In en, this message translates to:
  /// **'Sync in progress...'**
  String get syncInProgress;

  /// No description provided for @orderDetails.
  ///
  /// In en, this message translates to:
  /// **'Order Details'**
  String get orderDetails;

  /// No description provided for @totalBillAmount.
  ///
  /// In en, this message translates to:
  /// **'Total Bill Amount'**
  String get totalBillAmount;

  /// No description provided for @balanceDue.
  ///
  /// In en, this message translates to:
  /// **'Balance Due'**
  String get balanceDue;

  /// No description provided for @paymentType.
  ///
  /// In en, this message translates to:
  /// **'Payment Type'**
  String get paymentType;

  /// No description provided for @totalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total Amount'**
  String get totalAmount;

  /// No description provided for @receiptNumber.
  ///
  /// In en, this message translates to:
  /// **'Receipt Number'**
  String get receiptNumber;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @customerDetails.
  ///
  /// In en, this message translates to:
  /// **'Customer Details'**
  String get customerDetails;

  /// No description provided for @customerName.
  ///
  /// In en, this message translates to:
  /// **'Customer Name'**
  String get customerName;

  /// No description provided for @mobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile Number'**
  String get mobileNumber;

  /// No description provided for @orderedItems.
  ///
  /// In en, this message translates to:
  /// **'Ordered Items'**
  String get orderedItems;

  /// No description provided for @noItemsFound.
  ///
  /// In en, this message translates to:
  /// **'No items found'**
  String get noItemsFound;

  /// No description provided for @orderSummary.
  ///
  /// In en, this message translates to:
  /// **'Order Summary'**
  String get orderSummary;

  /// No description provided for @paymentRecorded.
  ///
  /// In en, this message translates to:
  /// **'Payment recorded! 🎉'**
  String get paymentRecorded;

  /// No description provided for @failedToSavePayment.
  ///
  /// In en, this message translates to:
  /// **'Failed to save payment.'**
  String get failedToSavePayment;

  /// No description provided for @transactionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Transaction deleted successfully'**
  String get transactionDeleted;

  /// No description provided for @failedToDeleteTransaction.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete transaction'**
  String get failedToDeleteTransaction;

  /// No description provided for @transactionAdded.
  ///
  /// In en, this message translates to:
  /// **'Transaction added'**
  String get transactionAdded;

  /// No description provided for @couldNotFindOrder.
  ///
  /// In en, this message translates to:
  /// **'Could not find order details.'**
  String get couldNotFindOrder;

  /// No description provided for @shopName.
  ///
  /// In en, this message translates to:
  /// **'Shop Name'**
  String get shopName;

  /// No description provided for @completeAddress.
  ///
  /// In en, this message translates to:
  /// **'Complete Address'**
  String get completeAddress;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @gstinOptional.
  ///
  /// In en, this message translates to:
  /// **'GSTIN (Optional)'**
  String get gstinOptional;

  /// No description provided for @upiIdOptional.
  ///
  /// In en, this message translates to:
  /// **'UPI ID (Optional)'**
  String get upiIdOptional;

  /// No description provided for @upiQrNote.
  ///
  /// In en, this message translates to:
  /// **'UPI ID is shown as Scan-to-Pay QR on your invoice'**
  String get upiQrNote;

  /// No description provided for @shopLogo.
  ///
  /// In en, this message translates to:
  /// **'Shop Logo'**
  String get shopLogo;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get chooseFromGallery;

  /// No description provided for @takeAPhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a Photo'**
  String get takeAPhoto;

  /// No description provided for @removeLogo.
  ///
  /// In en, this message translates to:
  /// **'Remove Logo'**
  String get removeLogo;

  /// No description provided for @termsAndConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions on Invoice'**
  String get termsAndConditions;

  /// No description provided for @whatsappNote.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp Bill/Reminder Note'**
  String get whatsappNote;

  /// No description provided for @shopType.
  ///
  /// In en, this message translates to:
  /// **'Shop Type'**
  String get shopType;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'PREVIEW'**
  String get preview;

  /// No description provided for @saveAndSync.
  ///
  /// In en, this message translates to:
  /// **'Save & Sync'**
  String get saveAndSync;

  /// No description provided for @shopDetailsSaved.
  ///
  /// In en, this message translates to:
  /// **'Shop details saved & synced'**
  String get shopDetailsSaved;

  /// No description provided for @autofillFromReceipt.
  ///
  /// In en, this message translates to:
  /// **'Autofill from Receipt / Card (AI Scan)'**
  String get autofillFromReceipt;

  /// No description provided for @aiExtractingDetails.
  ///
  /// In en, this message translates to:
  /// **'AI extracting shop details...'**
  String get aiExtractingDetails;

  /// No description provided for @autofillSuccess.
  ///
  /// In en, this message translates to:
  /// **'Autofilled successfully! Please review & save.'**
  String get autofillSuccess;

  /// No description provided for @failedToExtract.
  ///
  /// In en, this message translates to:
  /// **'Failed to extract receipt'**
  String get failedToExtract;

  /// No description provided for @scanReceiptCard.
  ///
  /// In en, this message translates to:
  /// **'Scan Receipt / Business Card'**
  String get scanReceiptCard;

  /// No description provided for @chooseLogoSource.
  ///
  /// In en, this message translates to:
  /// **'Choose Logo Source'**
  String get chooseLogoSource;

  /// No description provided for @failedToUploadLogo.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload logo'**
  String get failedToUploadLogo;

  /// No description provided for @myItemCatalogue.
  ///
  /// In en, this message translates to:
  /// **'My Item Catalogue'**
  String get myItemCatalogue;

  /// No description provided for @manageItemsAndPrices.
  ///
  /// In en, this message translates to:
  /// **'Manage items and prices'**
  String get manageItemsAndPrices;

  /// No description provided for @dashboardAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Dashboard Analytics'**
  String get dashboardAnalytics;

  /// No description provided for @viewSalesAndPurchases.
  ///
  /// In en, this message translates to:
  /// **'View sales and purchases'**
  String get viewSalesAndPurchases;

  /// No description provided for @viewUsageMetrics.
  ///
  /// In en, this message translates to:
  /// **'View real usage metrics'**
  String get viewUsageMetrics;

  /// No description provided for @versionInfo.
  ///
  /// In en, this message translates to:
  /// **'Version 1.0.0 · Built for Indian SMBs'**
  String get versionInfo;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get syncing;

  /// No description provided for @shopDetailsInfo.
  ///
  /// In en, this message translates to:
  /// **'This info appears on your invoices & syncs across devices'**
  String get shopDetailsInfo;

  /// No description provided for @deleteOrder.
  ///
  /// In en, this message translates to:
  /// **'Delete Order Record?'**
  String get deleteOrder;

  /// No description provided for @orderDeleted.
  ///
  /// In en, this message translates to:
  /// **'Order deleted successfully.'**
  String get orderDeleted;

  /// No description provided for @couldNotGenerateLink.
  ///
  /// In en, this message translates to:
  /// **'Could not generate secure receipt link. Please try again.'**
  String get couldNotGenerateLink;

  /// No description provided for @advancedFilters.
  ///
  /// In en, this message translates to:
  /// **'Advanced Filters'**
  String get advancedFilters;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear Filters'**
  String get clearFilters;

  /// No description provided for @noInvoicesFound.
  ///
  /// In en, this message translates to:
  /// **'No Invoices Found'**
  String get noInvoicesFound;

  /// No description provided for @adjustFilters.
  ///
  /// In en, this message translates to:
  /// **'Adjust your filters or sync new invoices.'**
  String get adjustFilters;

  /// No description provided for @groupViewBy.
  ///
  /// In en, this message translates to:
  /// **'GROUP VIEW BY'**
  String get groupViewBy;

  /// No description provided for @deleteSelected.
  ///
  /// In en, this message translates to:
  /// **'Delete Selected'**
  String get deleteSelected;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get selectAll;

  /// No description provided for @totalReceipts.
  ///
  /// In en, this message translates to:
  /// **'TOTAL RECEIPTS'**
  String get totalReceipts;

  /// No description provided for @totalAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'TOTAL AMOUNT'**
  String get totalAmountLabel;

  /// No description provided for @deleteSelectedConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete Selected?'**
  String get deleteSelectedConfirm;

  /// No description provided for @includedInItemPrices.
  ///
  /// In en, this message translates to:
  /// **'INCLUDED IN ITEM PRICES'**
  String get includedInItemPrices;

  /// No description provided for @saveTransaction.
  ///
  /// In en, this message translates to:
  /// **'Save Transaction'**
  String get saveTransaction;

  /// No description provided for @outLabel.
  ///
  /// In en, this message translates to:
  /// **'OUT'**
  String get outLabel;

  /// No description provided for @inLabel.
  ///
  /// In en, this message translates to:
  /// **'IN'**
  String get inLabel;

  /// No description provided for @uploadInvoices.
  ///
  /// In en, this message translates to:
  /// **'Upload Invoices'**
  String get uploadInvoices;

  /// No description provided for @scanPhotoOrSelect.
  ///
  /// In en, this message translates to:
  /// **'Scan, photo, or select files'**
  String get scanPhotoOrSelect;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @partiesKhataTitle.
  ///
  /// In en, this message translates to:
  /// **'PARTIES'**
  String get partiesKhataTitle;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @tapToSetUp.
  ///
  /// In en, this message translates to:
  /// **'Tap to set up'**
  String get tapToSetUp;

  /// No description provided for @addFirstItem.
  ///
  /// In en, this message translates to:
  /// **'Add First Item'**
  String get addFirstItem;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @noDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get noDataAvailable;

  /// No description provided for @errorLabel.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get errorLabel;

  /// No description provided for @noDataForPeriod.
  ///
  /// In en, this message translates to:
  /// **'No data for this period'**
  String get noDataForPeriod;

  /// No description provided for @failedToLoadImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to load receipt image.'**
  String get failedToLoadImage;

  /// No description provided for @noCreditBookEntry.
  ///
  /// In en, this message translates to:
  /// **'No credit book entry found for this customer yet.'**
  String get noCreditBookEntry;
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
      <String>['en', 'mr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'mr':
      return AppLocalizationsMr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
