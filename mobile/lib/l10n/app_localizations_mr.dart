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

  // Extended strings — override parent defaults with Marathi-English mix
  @override String get save => 'Save करा';
  @override String get cancel => 'Cancel';
  @override String get deleteAction => 'Delete करा';
  @override String get confirm => 'Confirm करा';
  @override String get retry => 'पुन्हा प्रयत्न';
  @override String get search => 'शोधा...';
  @override String get searchCustomersVendors => 'Customer किंवा Supplier शोधा...';
  @override String get noPartiesFound => 'कोणतेही Parties सापडले नाही';
  @override String get addCustomerOrSupplier => 'Khata track करण्यासाठी Customer किंवा Supplier जोडा.';
  @override String get allParties => 'सर्व';
  @override String get pendingParties => 'Pending';
  @override String get customers => 'Customers';
  @override String get suppliers => 'Suppliers';
  @override String get gallaCounter => 'Galla';
  @override String get deleteParties => 'Parties Delete करा';
  @override String deletePartiesConfirm(int count) => '$count parties delete करायच्या आहेत का?';
  @override String get selected => 'निवडले';
  @override String get total => 'एकूण';
  @override String get goodMorning => 'शुभ सकाळ,';
  @override String get goodAfternoon => 'शुभ दुपार,';
  @override String get goodEvening => 'शुभ संध्याकाळ,';
  @override String get reviewPendingInvoices => 'Pending invoices तपासा';
  @override String get syncInProgress => 'Sync चालू आहे...';
  @override String get orderDetails => 'Order Details';
  @override String get totalBillAmount => 'एकूण Bill Amount';
  @override String get balanceDue => 'Balance बाकी';
  @override String get paymentType => 'Payment Type';
  @override String get totalAmount => 'एकूण Amount';
  @override String get receiptNumber => 'Receipt Number';
  @override String get date => 'दिनांक';
  @override String get customerDetails => 'Customer Details';
  @override String get customerName => 'Customer चे नाव';
  @override String get mobileNumber => 'Mobile Number';
  @override String get orderedItems => 'Order केलेले Items';
  @override String get noItemsFound => 'कोणतेही Items सापडले नाही';
  @override String get orderSummary => 'Order Summary';
  @override String get paymentRecorded => 'Payment save झाली! 🎉';
  @override String get failedToSavePayment => 'Payment save झाली नाही';
  @override String get transactionDeleted => 'Transaction delete झाली';
  @override String get failedToDeleteTransaction => 'Transaction delete झाली नाही';
  @override String get transactionAdded => 'Transaction जोडली';
  @override String get couldNotFindOrder => 'Order details सापडले नाही';
  @override String get shopName => 'दुकानाचे नाव';
  @override String get completeAddress => 'पूर्ण Address';
  @override String get phoneNumber => 'Phone Number';
  @override String get gstinOptional => 'GSTIN (Optional)';
  @override String get upiIdOptional => 'UPI ID (Optional)';
  @override String get upiQrNote => 'UPI ID invoice वर Scan-to-Pay QR म्हणून दिसते';
  @override String get shopLogo => 'दुकानाचा Logo';
  @override String get chooseFromGallery => 'Gallery मधून निवडा';
  @override String get takeAPhoto => 'Photo काढा';
  @override String get removeLogo => 'Logo काढा';
  @override String get termsAndConditions => 'Invoice वरील Terms & Conditions';
  @override String get whatsappNote => 'WhatsApp Bill/Reminder Note';
  @override String get shopType => 'दुकानाचा प्रकार';
  @override String get preview => 'PREVIEW';
  @override String get saveAndSync => 'Save & Sync';
  @override String get shopDetailsSaved => 'दुकान details save & sync झाले';
  @override String get autofillFromReceipt => 'Receipt / Card मधून Autofill करा (AI Scan)';
  @override String get aiExtractingDetails => 'AI दुकान details काढत आहे...';
  @override String get autofillSuccess => 'Autofill यशस्वी! कृपया तपासा आणि Save करा.';
  @override String get failedToExtract => 'Receipt काढण्यात अडचण आली';
  @override String get scanReceiptCard => 'Receipt / Business Card Scan करा';
  @override String get chooseLogoSource => 'Logo Source निवडा';
  @override String get failedToUploadLogo => 'Logo upload झाला नाही';
  @override String get myItemCatalogue => 'माझा Item Catalogue';
  @override String get manageItemsAndPrices => 'Items आणि Prices manage करा';
  @override String get dashboardAnalytics => 'Dashboard Analytics';
  @override String get viewSalesAndPurchases => 'Sales आणि Purchases पहा';
  @override String get viewUsageMetrics => 'Real Usage Metrics पहा';
  @override String get versionInfo => 'Version 1.0.0 · Indian SMBs साठी';
  @override String get syncing => 'Sync होत आहे...';
  @override String get shopDetailsInfo => 'ही माहिती तुमच्या invoices वर दिसते आणि सर्व devices वर sync होते';
  @override String get deleteOrder => 'Order Record Delete करायचा?';
  @override String get orderDeleted => 'Order delete झाला';
  @override String get couldNotGenerateLink => 'Secure receipt link मिळवता आला नाही. पुन्हा प्रयत्न करा.';
  @override String get advancedFilters => 'Advanced Filters';
  @override String get clearAll => 'सर्व Clear करा';
  @override String get clearFilters => 'Filters Clear करा';
  @override String get noInvoicesFound => 'कोणतेही Invoices सापडले नाही';
  @override String get adjustFilters => 'Filters बदला किंवा नवीन Invoices Sync करा.';
  @override String get groupViewBy => 'GROUP VIEW BY';
  @override String get deleteSelected => 'निवडलेले Delete करा';
  @override String get selectAll => 'सर्व निवडा';
  @override String get totalReceipts => 'एकूण Receipts';
  @override String get totalAmountLabel => 'एकूण AMOUNT';
  @override String get deleteSelectedConfirm => 'निवडलेले Delete करायचे?';
  @override String get includedInItemPrices => 'ITEM PRICES मध्ये INCLUDED';
  @override String get saveTransaction => 'Transaction Save करा';
  @override String get outLabel => 'OUT';
  @override String get inLabel => 'IN';
  @override String get uploadInvoices => 'Invoices Upload करा';
  @override String get scanPhotoOrSelect => 'Scan, Photo, किंवा Files निवडा';
  @override String get clear => 'Clear करा';
  @override String get partiesKhataTitle => 'Parties (Khata)';
  @override String get dashboard => 'Dashboard';
  @override String get tapToSetUp => 'Setup करण्यासाठी tap करा';
  @override String get addFirstItem => 'पहिला Item जोडा';
  @override String get done => 'Done';
  @override String get edit => 'Edit';
  @override String get remove => 'Remove करा';
  @override String get noDataAvailable => 'कोणताही Data उपलब्ध नाही';
  @override String get errorLabel => 'Error';
  @override String get noDataForPeriod => 'या कालावधीसाठी Data नाही';
  @override String get failedToLoadImage => 'Receipt image load झाली नाही.';
  @override String get noCreditBookEntry => 'या Customer साठी अजून Credit Book entry नाही.';
}
