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

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get deleteAction => 'Delete';

  @override
  String get confirm => 'Confirm';

  @override
  String get retry => 'Retry';

  @override
  String get search => 'Search...';

  @override
  String get searchCustomersVendors => 'Search customers or vendors...';

  @override
  String get noPartiesFound => 'No parties found';

  @override
  String get addCustomerOrSupplier => 'Add customers or suppliers to track Khata.';

  @override
  String get allParties => 'All';

  @override
  String get pendingParties => 'Pending';

  @override
  String get customers => 'Customers';

  @override
  String get suppliers => 'Suppliers';

  @override
  String get gallaCounter => 'Dashboard';

  @override
  String get deleteParties => 'Delete Parties';

  @override
  String deletePartiesConfirm(int count) => 'Are you sure you want to delete $count parties?';

  @override
  String get selected => 'Selected';

  @override
  String get total => 'TOTAL';

  @override
  String get goodMorning => 'Good morning,';

  @override
  String get goodAfternoon => 'Good afternoon,';

  @override
  String get goodEvening => 'Good evening,';

  @override
  String get reviewPendingInvoices => 'Review pending invoices';

  @override
  String get syncInProgress => 'Sync in progress...';

  @override
  String get orderDetails => 'Order Details';

  @override
  String get totalBillAmount => 'Total Bill Amount';

  @override
  String get balanceDue => 'Balance Due';

  @override
  String get paymentType => 'Payment Type';

  @override
  String get totalAmount => 'Total Amount';

  @override
  String get receiptNumber => 'Receipt Number';

  @override
  String get date => 'Date';

  @override
  String get customerDetails => 'Customer Details';

  @override
  String get customerName => 'Customer Name';

  @override
  String get mobileNumber => 'Mobile Number';

  @override
  String get orderedItems => 'Ordered Items';

  @override
  String get noItemsFound => 'No items found';

  @override
  String get orderSummary => 'Order Summary';

  @override
  String get paymentRecorded => 'Payment recorded! 🎉';

  @override
  String get failedToSavePayment => 'Failed to save payment.';

  @override
  String get transactionDeleted => 'Transaction deleted successfully';

  @override
  String get failedToDeleteTransaction => 'Failed to delete transaction';

  @override
  String get transactionAdded => 'Transaction added';

  @override
  String get couldNotFindOrder => 'Could not find order details.';

  @override
  String get shopName => 'Shop Name';

  @override
  String get completeAddress => 'Complete Address';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get gstinOptional => 'GSTIN (Optional)';

  @override
  String get upiIdOptional => 'UPI ID (Optional)';

  @override
  String get upiQrNote => 'UPI ID is shown as Scan-to-Pay QR on your invoice';

  @override
  String get shopLogo => 'Shop Logo';

  @override
  String get chooseFromGallery => 'Choose from Gallery';

  @override
  String get takeAPhoto => 'Take a Photo';

  @override
  String get removeLogo => 'Remove Logo';

  @override
  String get termsAndConditions => 'Terms & Conditions on Invoice';

  @override
  String get whatsappNote => 'WhatsApp Bill/Reminder Note';

  @override
  String get shopType => 'Shop Type';

  @override
  String get preview => 'PREVIEW';

  @override
  String get saveAndSync => 'Save & Sync';

  @override
  String get shopDetailsSaved => 'Shop details saved & synced';

  @override
  String get autofillFromReceipt => 'Autofill from Receipt / Card (AI Scan)';

  @override
  String get aiExtractingDetails => 'AI extracting shop details...';

  @override
  String get autofillSuccess => 'Autofilled successfully! Please review & save.';

  @override
  String get failedToExtract => 'Failed to extract receipt';

  @override
  String get scanReceiptCard => 'Scan Receipt / Business Card';

  @override
  String get chooseLogoSource => 'Choose Logo Source';

  @override
  String get failedToUploadLogo => 'Failed to upload logo';

  @override
  String get myItemCatalogue => 'My Item Catalogue';

  @override
  String get manageItemsAndPrices => 'Manage items and prices';

  @override
  String get dashboardAnalytics => 'Dashboard Analytics';

  @override
  String get viewSalesAndPurchases => 'View sales and purchases';

  @override
  String get viewUsageMetrics => 'View real usage metrics';

  @override
  String get versionInfo => 'Version 1.0.0 · Built for Indian SMBs';

  @override
  String get syncing => 'Syncing...';

  @override
  String get shopDetailsInfo => 'This info appears on your invoices & syncs across devices';

  @override
  String get deleteOrder => 'Delete Order Record?';

  @override
  String get orderDeleted => 'Order deleted successfully.';

  @override
  String get couldNotGenerateLink => 'Could not generate secure receipt link. Please try again.';

  @override
  String get advancedFilters => 'Advanced Filters';

  @override
  String get clearAll => 'Clear All';

  @override
  String get clearFilters => 'Clear Filters';

  @override
  String get noInvoicesFound => 'No Invoices Found';

  @override
  String get adjustFilters => 'Adjust your filters or sync new invoices.';

  @override
  String get groupViewBy => 'GROUP VIEW BY';

  @override
  String get deleteSelected => 'Delete Selected';

  @override
  String get selectAll => 'Select All';

  @override
  String get totalReceipts => 'TOTAL RECEIPTS';

  @override
  String get totalAmountLabel => 'TOTAL AMOUNT';

  @override
  String get deleteSelectedConfirm => 'Delete Selected?';

  @override
  String get includedInItemPrices => 'INCLUDED IN ITEM PRICES';

  @override
  String get saveTransaction => 'Save Transaction';

  @override
  String get outLabel => 'OUT';

  @override
  String get inLabel => 'IN';

  @override
  String get uploadInvoices => 'Upload Invoices';

  @override
  String get scanPhotoOrSelect => 'Scan, photo, or select files';

  @override
  String get clear => 'Clear';

  @override
  String get partiesKhataTitle => 'PARTIES';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get tapToSetUp => 'Tap to set up';

  @override
  String get addFirstItem => 'Add First Item';

  @override
  String get done => 'Done';

  @override
  String get edit => 'Edit';

  @override
  String get remove => 'Remove';

  @override
  String get noDataAvailable => 'No data available';

  @override
  String get errorLabel => 'Error';

  @override
  String get noDataForPeriod => 'No data for this period';

  @override
  String get failedToLoadImage => 'Failed to load receipt image.';

  @override
  String get noCreditBookEntry => 'No credit book entry found for this customer yet.';
}
