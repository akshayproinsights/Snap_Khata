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
  String get quickActions => 'Quick Actions';

  @override
  String get reviewSync => 'Bill चेक करा';

  @override
  String get unmappedItems => 'नवीन माल';

  @override
  String get outOfStock => 'Stock संपला';

  @override
  String get totalSales => 'एकूण Sales';

  @override
  String get processNow => 'आता Process करा';

  @override
  String get mapItems => 'Item जोडा';

  @override
  String get restockList => 'Stock भरा';

  @override
  String get language => 'भाषा';

  @override
  String get selectLanguage => 'भाषा निवडा';

  @override
  String get settings => 'Settings';

  @override
  String get preferences => 'प्राधान्ये';

  @override
  String get shopDetails => 'दुकान Details';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get ordersProcessed => 'Orders';

  @override
  String get account => 'Account';

  @override
  String get logOut => 'Log Out';

  @override
  String get about => 'आमच्याबद्दल';

  @override
  String get partiesKhata => 'Parties / खाते';

  @override
  String get toCollect => 'येणे बाकी';

  @override
  String get toGive => 'देणे बाकी';

  @override
  String get scanBill => 'Bill Scan करा';

  // Extended strings
  String get save => 'Save करा';
  String get cancel => 'Cancel';
  String get deleteAction => 'Delete करा';
  String get confirm => 'Confirm करा';
  String get retry => 'पुन्हा प्रयत्न';
  String get search => 'शोधा...';
  String get searchCustomersVendors => 'Customer किंवा Supplier शोधा...';
  String get noPartiesFound => 'कोणतेही Parties सापडले नाही';
  String get addCustomerOrSupplier => 'Khata track करण्यासाठी Customer किंवा Supplier जोडा.';
  String get allParties => 'सर्व';
  String get pendingParties => 'Pending';
  String get customers => 'Customers';
  String get suppliers => 'Suppliers';
  String get gallaCounter => 'Galla';
  String get deleteParties => 'Parties Delete करा';
  String get selected => 'निवडले';
  String get total => 'एकूण';
  String get goodMorning => 'शुभ सकाळ,';
  String get goodAfternoon => 'शुभ दुपार,';
  String get goodEvening => 'शुभ संध्याकाळ,';
  String get reviewPendingInvoices => 'Pending invoices तपासा';
  String get syncInProgress => 'Sync चालू आहे...';
  String get orderDetails => 'Order Details';
  String get totalBillAmount => 'एकूण Bill Amount';
  String get balanceDue => 'Balance बाकी';
  String get paymentType => 'Payment Type';
  String get totalAmount => 'एकूण Amount';
  String get receiptNumber => 'Receipt Number';
  String get date => 'दिनांक';
  String get customerDetails => 'Customer Details';
  String get customerName => 'Customer चे नाव';
  String get mobileNumber => 'Mobile Number';
  String get orderedItems => 'Order केलेले Items';
  String get noItemsFound => 'कोणतेही Items सापडले नाही';
  String get orderSummary => 'Order Summary';
  String get paymentRecorded => 'Payment save झाली! 🎉';
  String get failedToSavePayment => 'Payment save झाली नाही';
  String get transactionDeleted => 'Transaction delete झाली';
  String get failedToDeleteTransaction => 'Transaction delete झाली नाही';
  String get transactionAdded => 'Transaction जोडली';
  String get couldNotFindOrder => 'Order details सापडले नाही';
  String get shopName => 'दुकानाचे नाव';
  String get completeAddress => 'पूर्ण Address';
  String get phoneNumber => 'Phone Number';
  String get gstinOptional => 'GSTIN (Optional)';
  String get upiIdOptional => 'UPI ID (Optional)';
  String get upiQrNote => 'UPI ID invoice वर Scan-to-Pay QR म्हणून दिसते';
  String get shopLogo => 'दुकानाचा Logo';
  String get chooseFromGallery => 'Gallery मधून निवडा';
  String get takeAPhoto => 'Photo काढा';
  String get removeLogo => 'Logo काढा';
  String get termsAndConditions => 'Invoice वरील Terms & Conditions';
  String get whatsappNote => 'WhatsApp Bill/Reminder Note';
  String get shopType => 'दुकानाचा प्रकार';
  String get preview => 'PREVIEW';
  String get saveAndSync => 'Save & Sync';
  String get shopDetailsSaved => 'दुकान details save & sync झाले';
  String get autofillFromReceipt => 'Receipt / Card मधून Autofill करा (AI Scan)';
  String get aiExtractingDetails => 'AI दुकान details काढत आहे...';
  String get autofillSuccess => 'Autofill यशस्वी! कृपया तपासा आणि Save करा.';
  String get failedToExtract => 'Receipt काढण्यात अडचण आली';
  String get scanReceiptCard => 'Receipt / Business Card Scan करा';
  String get chooseLogoSource => 'Logo Source निवडा';
  String get failedToUploadLogo => 'Logo upload झाला नाही';
  String get myItemCatalogue => 'माझा Item Catalogue';
  String get manageItemsAndPrices => 'Items आणि Prices manage करा';
  String get dashboardAnalytics => 'Dashboard Analytics';
  String get viewSalesAndPurchases => 'Sales आणि Purchases पहा';
  String get viewUsageMetrics => 'Real Usage Metrics पहा';
  String get versionInfo => 'Version 1.0.0 · Indian SMBs साठी';
  String get syncing => 'Sync होत आहे...';
  String get shopDetailsInfo => 'ही माहिती तुमच्या invoices वर दिसते आणि सर्व devices वर sync होते';
  String get deleteOrder => 'Order Record Delete करायचा?';
  String get orderDeleted => 'Order delete झाला';
  String get couldNotGenerateLink => 'Secure receipt link मिळवता आला नाही. पुन्हा प्रयत्न करा.';
  String get advancedFilters => 'Advanced Filters';
  String get clearAll => 'सर्व Clear करा';
  String get clearFilters => 'Filters Clear करा';
  String get noInvoicesFound => 'कोणतेही Invoices सापडले नाही';
  String get adjustFilters => 'Filters बदला किंवा नवीन Invoices Sync करा.';
  String get groupViewBy => 'GROUP VIEW BY';
  String get deleteSelected => 'निवडलेले Delete करा';
  String get selectAll => 'सर्व निवडा';
  String get totalReceipts => 'एकूण Receipts';
  String get totalAmountLabel => 'एकूण AMOUNT';
  String get deleteSelectedConfirm => 'निवडलेले Delete करायचे?';
  String get includedInItemPrices => 'ITEM PRICES मध्ये INCLUDED';
  String get saveTransaction => 'Transaction Save करा';
  String get outLabel => 'OUT';
  String get inLabel => 'IN';
  String get uploadInvoices => 'Invoices Upload करा';
  String get scanPhotoOrSelect => 'Scan, Photo, किंवा Files निवडा';
  String get clear => 'Clear करा';
  String get partiesKhataTitle => 'Parties (Khata)';
  String get dashboard => 'Dashboard';
  String get tapToSetUp => 'Setup करण्यासाठी tap करा';
  String get addFirstItem => 'पहिला Item जोडा';
  String get done => 'Done';
  String get edit => 'Edit';
  String get remove => 'Remove करा';
  String get noDataAvailable => 'कोणताही Data उपलब्ध नाही';
  String get errorLabel => 'Error';
  String get noDataForPeriod => 'या कालावधीसाठी Data नाही';
  String get failedToLoadImage => 'Receipt image load झाली नाही.';
  String get noCreditBookEntry => 'या Customer साठी अजून Credit Book entry नाही.';
}
