import React, { useState, useEffect, useMemo, useRef } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useOutletContext } from 'react-router-dom';
import { toast } from 'react-hot-toast';
import { udharAPI } from '../services/udharAPI';
import type { Ledger, Transaction } from '../services/udharAPI';
import { formatCurrency, formatActivityDate } from '../utils/dashboardHelpers';
import {
    Users,
    Truck,
    Search,
    Plus,
    Clock,
    FileText,
    ChevronRight,
    ArrowUpRight,
    ArrowDownLeft,
    X,
    Image,
    FileDown,
    MessageCircle,
    Send
} from 'lucide-react';

// ── Payment Reminder Modal ───────────────────────────────────────────────────
interface ReminderModalProps {
    ledger: Ledger;
    onClose: () => void;
}

const ReminderModal: React.FC<ReminderModalProps> = ({ ledger, onClose }) => {
    type ShareMode = 'receiptPhoto' | 'accountStatement';
    const [shareMode, setShareMode] = useState<ShareMode>('accountStatement');
    const [phoneInput, setPhoneInput] = useState('');
    const [isPdfLoading, setIsPdfLoading] = useState(false);
    const backdropRef = useRef<HTMLDivElement>(null);

    const name = ledger.customer_name || ledger.vendor_name || 'Customer';
    const balanceDue = ledger.balance_due;
    const totalBilled = ledger.latest_bill_amount || balanceDue;
    const billNo = ledger.latest_bill_number;

    // Detect if this ledger might have a receipt image (based on bill number)
    const hasReceiptPhoto = !!(ledger.latest_bill_number);

    // Build WhatsApp message preview
    const message = [
        `Hi ${name},`,
        '',
        `⚠️ *Amount Due: ${formatCurrency(balanceDue)}*${billNo ? ` (Bill #${billNo})` : ''}`,
        '',
        'Please settle this amount as soon as possible.',
        '',
        'Thank you! 🙏',
    ].join('\n');

    const handleWhatsApp = () => {
        const phone = phoneInput.trim();
        const encodedMsg = encodeURIComponent(message);
        if (phone) {
            const cleaned = phone.replace(/\D/g, '');
            const num = cleaned.startsWith('91') ? cleaned : `91${cleaned}`;
            window.open(`https://wa.me/${num}?text=${encodedMsg}`, '_blank');
        } else {
            // Share without number — opens WhatsApp picker
            window.open(`https://wa.me/?text=${encodedMsg}`, '_blank');
        }
        onClose();
    };

    const handleSharePdf = async () => {
        setIsPdfLoading(true);
        try {
            // Fetch full transaction history first
            let transactions: Transaction[] = [];
            try {
                const result = await udharAPI.getTransactions(ledger.id);
                transactions = result.data ?? [];
            } catch (_) {
                // If fetch fails, still generate a summary-only PDF
            }

            const printWindow = window.open('', '_blank', 'width=800,height=600');
            if (!printWindow) {
                toast.error('Please allow pop-ups to download the PDF.');
                setIsPdfLoading(false);
                return;
            }

            const date = new Date().toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });

            // Build transaction table rows
            let runningBalance = 0;
            const txRows = transactions
                .slice()
                .sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime())
                .map(tx => {
                    const isInvoice = tx.transaction_type === 'INVOICE';
                    if (isInvoice) runningBalance += tx.amount;
                    else runningBalance -= tx.amount;
                    const txDate = new Date(tx.created_at).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
                    return `
                    <tr style="border-bottom:1px solid #f1f5f9;">
                        <td style="padding:10px 12px;font-size:12px;color:#64748b;">${txDate}</td>
                        <td style="padding:10px 12px;font-size:12px;font-weight:600;color:${isInvoice ? '#1e293b' : '#16a34a'};">
                            ${isInvoice ? 'Credit Sale' : 'Payment'}
                        </td>
                        <td style="padding:10px 12px;font-size:12px;color:#64748b;">${tx.receipt_number ?? tx.invoice_number ?? '—'}</td>
                        <td style="padding:10px 12px;font-size:12px;text-align:right;font-weight:600;color:${isInvoice ? '#dc2626' : '#16a34a'};">
                            ${isInvoice ? '+' : '-'} ${formatCurrency(tx.amount)}
                        </td>
                        <td style="padding:10px 12px;font-size:12px;text-align:right;font-weight:700;color:${runningBalance > 0 ? '#dc2626' : '#16a34a'};">
                            ${formatCurrency(Math.abs(runningBalance))}
                        </td>
                    </tr>`;
                }).join('');

            const txTableHtml = transactions.length > 0 ? `
            <div style="padding:20px 24px 0;border-top:1px solid #e2e8f0;">
                <p style="font-size:11px;font-weight:700;text-transform:uppercase;color:#64748b;letter-spacing:0.8px;margin-bottom:12px;">
                    Transaction History (${transactions.length} entries)
                </p>
                <table style="width:100%;border-collapse:collapse;">
                    <thead>
                        <tr style="background:#f8fafc;border-bottom:2px solid #1e293b;">
                            <th style="padding:8px 12px;font-size:11px;text-align:left;color:#64748b;font-weight:700;text-transform:uppercase;letter-spacing:0.5px;">Date</th>
                            <th style="padding:8px 12px;font-size:11px;text-align:left;color:#64748b;font-weight:700;text-transform:uppercase;letter-spacing:0.5px;">Type</th>
                            <th style="padding:8px 12px;font-size:11px;text-align:left;color:#64748b;font-weight:700;text-transform:uppercase;letter-spacing:0.5px;">Bill #</th>
                            <th style="padding:8px 12px;font-size:11px;text-align:right;color:#64748b;font-weight:700;text-transform:uppercase;letter-spacing:0.5px;">Amount</th>
                            <th style="padding:8px 12px;font-size:11px;text-align:right;color:#64748b;font-weight:700;text-transform:uppercase;letter-spacing:0.5px;">Balance</th>
                        </tr>
                    </thead>
                    <tbody>${txRows}</tbody>
                </table>
            </div>` : '';

            printWindow.document.write(`
<!DOCTYPE html>
<html>
<head>
  <title>Account Statement - ${name}</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: Arial, sans-serif; color: #1e293b; padding: 32px; }
    .header { background: #1a2744; color: white; padding: 20px 24px; }
    .header h1 { font-size: 20px; letter-spacing: 1px; }
    .header p { font-size: 11px; color: #94a3b8; margin-top: 3px; }
    .sub-header { background: #f1f5f9; padding: 8px 24px; font-size: 11px; color: #64748b; border-bottom: 1px solid #e2e8f0; }
    .outer { border: 1.5px solid #1e293b; border-radius: 0 0 6px 6px; }
    .meta { display: flex; justify-content: space-between; padding: 16px 24px; border-bottom: 1px solid #e2e8f0; }
    .meta-block h3 { font-size: 10px; color: #64748b; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 4px; }
    .meta-block p { font-size: 14px; font-weight: bold; }
    .summary { display: flex; padding: 16px 24px; gap: 16px; border-bottom: 1px solid #e2e8f0; }
    .chip { flex: 1; text-align: center; padding: 12px 8px; border: 1px solid #e2e8f0; border-radius: 6px; }
    .chip label { font-size: 9px; text-transform: uppercase; letter-spacing: 0.5px; color: #64748b; display: block; margin-bottom: 4px; }
    .chip strong { font-size: 16px; display: block; }
    .due { color: #dc2626; }
    .paid-color { color: #16a34a; }
    .footer { padding: 14px 24px; font-size: 10px; color: #94a3b8; text-align: center; border-top: 1px solid #f1f5f9; }
    @media print {
      body { padding: 0; }
      @page { size: A4; margin: 12mm 14mm; }
    }
  </style>
</head>
<body>
  <div class="header">
    <h1>ACCOUNT STATEMENT</h1>
    <p>Powered by SnapKhata</p>
  </div>
  <div class="sub-header">Generated on ${date}</div>
  <div class="outer">
    <div class="meta">
      <div class="meta-block">
        <h3>Customer / Party</h3>
        <p>${name}</p>
      </div>
      <div class="meta-block" style="text-align:right">
        <h3>Status</h3>
        <p style="color:${balanceDue > 0 ? '#dc2626' : '#16a34a'};font-size:13px;">
          ${balanceDue > 0 ? '⚠ UNPAID' : '✓ SETTLED'}
        </p>
      </div>
    </div>
    <div class="summary">
      <div class="chip"><label>Total Billed</label><strong>${formatCurrency(totalBilled)}</strong></div>
      <div class="chip"><label>Total Paid</label><strong class="paid-color">${formatCurrency(Math.max(0, totalBilled - balanceDue))}</strong></div>
      <div class="chip"><label>Balance Due</label><strong class="${balanceDue > 0 ? 'due' : 'paid-color'}">${formatCurrency(balanceDue)}</strong></div>
    </div>
    ${txTableHtml}
    <div class="footer">
      This is a computer-generated statement &nbsp;·&nbsp; snapkhata.com
    </div>
  </div>
</body>
</html>`);
            printWindow.document.close();
            printWindow.focus();
            setTimeout(() => {
                printWindow.print();
                printWindow.close();
            }, 500);
        } catch (err) {
            console.error(err);
            toast.error('Could not generate PDF.');
        } finally {
            setIsPdfLoading(false);
        }
    };

    // Close on backdrop click
    const handleBackdropClick = (e: React.MouseEvent) => {
        if (e.target === backdropRef.current) onClose();
    };

    return (
        <div
            ref={backdropRef}
            onClick={handleBackdropClick}
            className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/40 backdrop-blur-sm"
            style={{ animation: 'fadeIn 0.15s ease' }}
        >
            <div className="w-full sm:max-w-md bg-white rounded-t-3xl sm:rounded-3xl shadow-2xl flex flex-col max-h-[90vh] overflow-hidden"
                 style={{ animation: 'slideUp 0.2s ease' }}
            >
                {/* Header */}
                <div className="flex items-start justify-between p-6 pb-4">
                    <div>
                        <h2 className="text-xl font-black text-gray-900 leading-tight">Send Payment Reminder</h2>
                        <p className="text-sm text-gray-500 font-semibold mt-0.5">{name}</p>
                    </div>
                    <button onClick={onClose} className="p-2 rounded-xl hover:bg-gray-100 text-gray-400 hover:text-gray-600 transition-colors -mt-1 -mr-1">
                        <X size={20} />
                    </button>
                </div>

                {/* Scroll content */}
                <div className="flex-1 overflow-y-auto px-6 space-y-5">
                    {/* Summary Strip */}
                    <div className="flex items-center justify-around bg-gray-50 rounded-2xl border border-gray-100 p-4">
                        <div className="text-center">
                            <p className="text-[10px] font-black text-gray-400 uppercase tracking-widest mb-1">Billed</p>
                            <p className="text-base font-black text-gray-900">{formatCurrency(totalBilled)}</p>
                        </div>
                        <div className="w-px h-8 bg-gray-200" />
                        <div className="text-center">
                            <p className="text-[10px] font-black text-gray-400 uppercase tracking-widest mb-1">Paid</p>
                            <p className="text-base font-black text-emerald-600">{formatCurrency(Math.max(0, totalBilled - balanceDue))}</p>
                        </div>
                        <div className="w-px h-8 bg-gray-200" />
                        <div className="text-center">
                            <p className="text-[10px] font-black text-gray-400 uppercase tracking-widest mb-1">Due</p>
                            <p className="text-base font-black text-rose-600">{formatCurrency(balanceDue)}</p>
                        </div>
                    </div>

                    {/* Send As Tabs */}
                    <div>
                        <p className="text-[11px] font-black text-gray-400 uppercase tracking-widest mb-3">Send As</p>
                        <div className="flex rounded-2xl border border-gray-200 overflow-hidden">
                            {hasReceiptPhoto && (
                                <button
                                    onClick={() => setShareMode('receiptPhoto')}
                                    className={`flex-1 flex items-center justify-center gap-2 py-3 text-sm font-bold transition-all ${
                                        shareMode === 'receiptPhoto'
                                            ? 'bg-indigo-600 text-white'
                                            : 'bg-white text-gray-600 hover:bg-gray-50'
                                    }`}
                                >
                                    <Image size={15} />
                                    Receipt Photo
                                </button>
                            )}
                            <button
                                onClick={() => setShareMode('accountStatement')}
                                className={`flex-1 flex items-center justify-center gap-2 py-3 text-sm font-bold transition-all ${
                                    shareMode === 'accountStatement'
                                        ? 'bg-indigo-600 text-white'
                                        : 'bg-white text-gray-600 hover:bg-gray-50'
                                } ${hasReceiptPhoto ? 'border-l border-gray-200' : ''}`}
                            >
                                <FileText size={15} />
                                Account Statement
                            </button>
                        </div>
                    </div>

                    {/* Message Preview */}
                    <div>
                        <p className="text-[11px] font-black text-gray-400 uppercase tracking-widest mb-3">Preview</p>
                        <div className="bg-[#DCF8C6] rounded-tr-2xl rounded-br-2xl rounded-bl-2xl p-4 shadow-sm">
                            <p className="text-sm text-gray-900 whitespace-pre-line leading-relaxed">{message}</p>
                        </div>
                    </div>

                    {/* Optional phone field */}
                    <div>
                        <label className="text-[11px] font-black text-gray-400 uppercase tracking-widest block mb-2">
                            Customer Mobile (optional)
                        </label>
                        <div className="flex items-center border border-gray-200 rounded-2xl overflow-hidden focus-within:border-indigo-500 focus-within:ring-2 focus-within:ring-indigo-500/10 transition-all">
                            <span className="px-3 py-3 text-sm font-bold text-gray-400 border-r border-gray-200 bg-gray-50">+91</span>
                            <input
                                type="tel"
                                placeholder="9876543210"
                                value={phoneInput}
                                onChange={(e) => setPhoneInput(e.target.value)}
                                className="flex-1 px-3 py-3 text-sm outline-none bg-white"
                            />
                        </div>
                    </div>

                    <div className="pb-2" />
                </div>

                {/* Action Buttons */}
                <div className="px-6 pb-6 pt-4 border-t border-gray-100 space-y-3">
                    {/* Share as PDF — only for Account Statement */}
                    {shareMode === 'accountStatement' && (
                        <button
                            onClick={handleSharePdf}
                            disabled={isPdfLoading}
                            className="w-full flex items-center justify-center gap-2 py-3.5 rounded-2xl border-2 border-indigo-500 text-indigo-600 font-black text-sm hover:bg-indigo-50 transition-all disabled:opacity-60"
                            style={{ background: 'rgba(99,102,241,0.06)' }}
                        >
                            <FileDown size={18} />
                            {isPdfLoading ? 'Preparing PDF…' : 'Share as PDF'}
                        </button>
                    )}

                    {/* Cancel + WhatsApp row */}
                    <div className="flex gap-3">
                        <button
                            onClick={onClose}
                            className="flex-1 py-3.5 rounded-2xl border border-gray-200 text-gray-700 font-bold text-sm hover:bg-gray-50 transition-all"
                        >
                            Cancel
                        </button>
                        <button
                            onClick={handleWhatsApp}
                            className="flex-[2] flex items-center justify-center gap-2 py-3.5 rounded-2xl font-black text-sm text-white transition-all hover:opacity-90 active:scale-[0.98]"
                            style={{ background: '#25D366' }}
                        >
                            <Send size={16} />
                            SEND ON WHATSAPP
                        </button>
                    </div>
                </div>
            </div>

            <style>{`
                @keyframes fadeIn { from { opacity: 0 } to { opacity: 1 } }
                @keyframes slideUp { from { transform: translateY(40px); opacity: 0 } to { transform: translateY(0); opacity: 1 } }
            `}</style>
        </div>
    );
};

const UdharDashboardPage: React.FC = () => {
    const queryClient = useQueryClient();
    const { setHeaderActions } = useOutletContext<{ setHeaderActions: (actions: React.ReactNode) => void }>();

    // Persistent toggle state for showing/hiding paid bills
    const [showPaidBills, setShowPaidBills] = useState<boolean>(() => {
        const saved = localStorage.getItem('udhar_show_paid_bills');
        return saved ? JSON.parse(saved) : false;
    });

    const [activeTab, setActiveTab] = useState<'customers' | 'suppliers'>('customers');
    const [searchTerm, setSearchTerm] = useState('');
    const [reminderLedger, setReminderLedger] = useState<Ledger | null>(null);

    // Persist toggle preference
    useEffect(() => {
        localStorage.setItem('udhar_show_paid_bills', JSON.stringify(showPaidBills));
    }, [showPaidBills]);

    // Fetch dashboard summary (TO COLLECT / TO PAY)
    const { data: summary, isLoading: summaryLoading, refetch: refetchSummary } = useQuery({
        queryKey: ['udharSummary'],
        queryFn: udharAPI.getSummary,
        staleTime: 0,
    });

    // Fetch customer ledgers
    const { data: customerLedgers, isLoading: customersLoading, refetch: refetchCustomers } = useQuery({
        queryKey: ['customerLedgers'],
        queryFn: udharAPI.getLedgers,
        staleTime: 0,
    });

    // Fetch vendor ledgers
    const { data: vendorLedgers, isLoading: vendorsLoading, refetch: refetchVendors } = useQuery({
        queryKey: ['vendorLedgers'],
        queryFn: udharAPI.getVendorLedgers,
        staleTime: 0,
    });

    // Auto-refresh every 30 seconds
    useEffect(() => {
        const interval = setInterval(() => {
            refetchSummary();
            refetchCustomers();
            refetchVendors();
        }, 30000);

        return () => clearInterval(interval);
    }, [refetchSummary, refetchCustomers, refetchVendors]);

    // Mutations
    const recordPaymentMutation = useMutation({
        mutationFn: ({ ledgerId, amount }: { ledgerId: number, amount: number }) => 
            udharAPI.recordPayment(ledgerId, amount, "Full payment"),
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['customerLedgers'] });
            queryClient.invalidateQueries({ queryKey: ['vendorLedgers'] });
            queryClient.invalidateQueries({ queryKey: ['udharSummary'] });
            toast.success("Payment recorded successfully!");
        },
        onError: (error: any) => {
            toast.error(error.message || "Failed to record payment");
        }
    });

    const handleRecordPayment = (ledgerId: number, amount: number) => {
        if (window.confirm(`Record full payment of ${formatCurrency(amount)}?`)) {
            recordPaymentMutation.mutate({ ledgerId, amount });
        }
    };

    // Filtering logic
    const filteredLedgers = useMemo(() => {
        const baseLedgers = activeTab === 'customers' ? (customerLedgers || []) : (vendorLedgers || []);
        
        return baseLedgers.filter(ledger => {
            const name = (ledger.customer_name || ledger.vendor_name || '').toLowerCase();
            const matchesSearch = name.includes(searchTerm.toLowerCase());
            
            const isPaid = ledger.balance_due <= 0;
            const matchesPaidFilter = showPaidBills || !isPaid;
            
            return matchesSearch && matchesPaidFilter;
        });
    }, [customerLedgers, vendorLedgers, activeTab, searchTerm, showPaidBills]);

    // Set header actions
    useEffect(() => {
        setHeaderActions(
            <div className="flex items-center gap-2">
                <button className="flex items-center gap-2 bg-indigo-600 text-white px-4 py-2 rounded-lg hover:bg-indigo-700 transition shadow-sm font-medium">
                    <Plus size={18} />
                    Add Party
                </button>
            </div>
        );
    }, [setHeaderActions]);

    return (
        <>
        <div className="max-w-4xl mx-auto space-y-6 pb-20">
            {/* Credit Summary Cards - horizontal Style */}
            <div className="grid grid-cols-2 gap-3 px-1">
                {/* TO COLLECT (Receivable) - GREEN */}
                <div className="bg-gradient-to-br from-emerald-50 to-white rounded-2xl p-4 border border-emerald-100 shadow-sm">
                    <div className="flex items-center gap-2 mb-1">
                        <div className="bg-emerald-100 p-1.5 rounded-lg text-emerald-600">
                            <ArrowDownLeft size={16} />
                        </div>
                        <span className="text-[10px] font-bold text-emerald-700 uppercase tracking-wider">To Collect</span>
                    </div>
                    <p className="text-2xl font-black text-emerald-600 tabular-nums">
                        {summaryLoading ? '...' : formatCurrency(summary?.total_receivable || 0)}
                    </p>
                </div>

                {/* TO PAY (Payable) - RED */}
                <div className="bg-gradient-to-br from-rose-50 to-white rounded-2xl p-4 border border-rose-100 shadow-sm">
                    <div className="flex items-center gap-2 mb-1">
                        <div className="bg-rose-100 p-1.5 rounded-lg text-rose-600">
                            <ArrowUpRight size={16} />
                        </div>
                        <span className="text-[10px] font-bold text-rose-700 uppercase tracking-wider">To Pay</span>
                    </div>
                    <p className="text-2xl font-black text-rose-600 tabular-nums">
                        {summaryLoading ? '...' : formatCurrency(summary?.total_payable || 0)}
                    </p>
                </div>
            </div>

            {/* Main Content Area */}
            <div className="bg-white rounded-3xl border border-gray-100 shadow-xl shadow-gray-200/50 overflow-hidden flex flex-col min-h-[600px]">
                {/* Search & Filters */}
                <div className="p-4 space-y-4 bg-gray-50/50 border-b border-gray-100">
                    <div className="relative">
                        <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400" size={20} />
                        <input 
                            type="text"
                            placeholder="Search Customers or Suppliers..."
                            value={searchTerm}
                            onChange={(e) => setSearchTerm(e.target.value)}
                            className="w-full pl-12 pr-4 py-3.5 bg-white border border-gray-200 rounded-2xl focus:outline-none focus:ring-4 focus:ring-indigo-500/10 focus:border-indigo-500 text-base transition-all shadow-sm"
                        />
                    </div>

                    <div className="flex gap-2">
                        <button 
                            onClick={() => setActiveTab('customers')}
                            className={`flex-1 py-3 px-4 rounded-xl font-bold text-sm transition-all flex items-center justify-center gap-2 ${
                                activeTab === 'customers' 
                                    ? 'bg-indigo-600 text-white shadow-lg shadow-indigo-200' 
                                    : 'bg-white text-gray-600 border border-gray-200'
                            }`}
                        >
                            <Users size={18} />
                            Customers
                        </button>
                        <button 
                            onClick={() => setActiveTab('suppliers')}
                            className={`flex-1 py-3 px-4 rounded-xl font-bold text-sm transition-all flex items-center justify-center gap-2 ${
                                activeTab === 'suppliers' 
                                    ? 'bg-indigo-600 text-white shadow-lg shadow-indigo-200' 
                                    : 'bg-white text-gray-600 border border-gray-200'
                            }`}
                        >
                            <Truck size={18} />
                            Suppliers
                        </button>
                    </div>

                    <div className="flex items-center justify-between px-1">
                        <div className="flex items-center gap-2">
                            <span className="text-xs font-bold text-gray-500 uppercase tracking-tighter">Show Paid Bills</span>
                            <label className="relative inline-flex items-center cursor-pointer">
                                <input 
                                    type="checkbox" 
                                    className="sr-only peer" 
                                    checked={showPaidBills}
                                    onChange={(e) => setShowPaidBills(e.target.checked)}
                                />
                                <div className="w-9 h-5 bg-gray-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-indigo-600"></div>
                            </label>
                        </div>
                        <span className="text-[10px] font-bold text-indigo-600 bg-indigo-50 px-2 py-1 rounded-md uppercase tracking-wider">
                            {filteredLedgers.length} {activeTab}
                        </span>
                    </div>
                </div>

                {/* Ledger List */}
                <div className="flex-1 overflow-auto p-3 space-y-3">
                    {(customersLoading || vendorsLoading) ? (
                        <div className="flex flex-col items-center justify-center py-20 space-y-4">
                            <div className="w-10 h-10 border-4 border-indigo-100 border-t-indigo-600 rounded-full animate-spin" />
                            <p className="text-sm text-gray-500 font-bold tracking-tight">Loading your Khata...</p>
                        </div>
                    ) : filteredLedgers.length === 0 ? (
                        <div className="flex flex-col items-center justify-center py-20 text-center px-6">
                            <div className="bg-gray-100 p-6 rounded-full text-gray-300 mb-6 border-4 border-white shadow-inner">
                                <Users size={48} />
                            </div>
                            <h3 className="text-xl font-black text-gray-900 mb-2">No {activeTab} Found</h3>
                            <p className="text-sm text-gray-500 max-w-[280px] leading-relaxed">
                                {searchTerm 
                                    ? `Could not find any match for "${searchTerm}"`
                                    : "Start by adding your first party to track bills and payments."
                                }
                            </p>
                        </div>
                    ) : (
                        filteredLedgers.map((ledger) => (
                            <PartyCard 
                                key={`${ledger.party_type}-${ledger.id}`}
                                ledger={ledger}
                                onPay={handleRecordPayment}
                                onReminder={setReminderLedger}
                            />
                        ))
                    )}
                </div>
            </div>
        </div>

        {/* Payment Reminder Modal */}
        {reminderLedger && (
            <ReminderModal
                ledger={reminderLedger!}
                onClose={() => setReminderLedger(null)}
            />
        )}
        </>
    );
};

interface PartyCardProps {
    ledger: Ledger;
    onPay: (id: number, amount: number) => void;
    onReminder: (ledger: Ledger) => void;
}

const PartyCard: React.FC<PartyCardProps> = ({ ledger, onPay, onReminder }) => {
    const isDue = ledger.balance_due > 0;
    const name = ledger.customer_name || ledger.vendor_name || 'Unnamed Party';
    
    return (
        <div className={`relative bg-white rounded-2xl border border-gray-100 shadow-sm hover:shadow-md transition-all active:scale-[0.98] group overflow-hidden ${!isDue ? 'opacity-90' : ''}`}>
            {/* Status Bar */}
            <div className={`absolute left-0 top-0 bottom-0 w-1.5 ${isDue ? 'bg-rose-500' : 'bg-emerald-500'}`} />
            
            <div className="p-4 pl-5">
                {/* Top Row: Type & Time */}
                <div className="flex items-center justify-between mb-3">
                    <div className="flex items-center gap-2">
                        <span className={`text-[10px] font-black px-2 py-0.5 rounded-md tracking-widest uppercase ${
                            ledger.party_type === 'CUSTOMER' ? 'bg-blue-50 text-blue-600' : 'bg-orange-50 text-orange-600'
                        }`}>
                            {ledger.party_type}
                        </span>
                        {ledger.latest_bill_date && (
                            <div className="flex items-center gap-1 text-[10px] font-bold text-gray-400">
                                <Clock size={10} />
                                <span>{formatActivityDate(ledger.latest_bill_date)}</span>
                            </div>
                        )}
                    </div>
                    {isDue ? (
                        <span className="text-[10px] font-black text-rose-500 bg-rose-50 px-2 py-0.5 rounded-md uppercase tracking-widest">Due</span>
                    ) : (
                        <span className="text-[10px] font-black text-emerald-600 bg-emerald-50 px-2 py-0.5 rounded-md uppercase tracking-widest">Settled</span>
                    )}
                </div>

                {/* Middle Row: Name & Balance */}
                <div className="flex items-center justify-between items-start mb-4">
                    <div className="flex items-center gap-3">
                        <div className={`w-12 h-12 rounded-2xl flex items-center justify-center text-lg font-black ${
                            isDue ? 'bg-gray-900 text-white' : 'bg-gray-100 text-gray-500'
                        }`}>
                            {name.charAt(0).toUpperCase()}
                        </div>
                        <div>
                            <h4 className="text-lg font-black text-gray-900 group-hover:text-indigo-600 transition-colors leading-tight">
                                {name}
                            </h4>
                            <p className="text-[11px] font-bold text-gray-400 uppercase tracking-tighter mt-0.5">
                                {ledger.party_type === 'CUSTOMER' ? 'Receivable' : 'Payable'}
                            </p>
                        </div>
                    </div>
                    <div className="text-right">
                        <div className={`text-xl font-black tabular-nums leading-none mb-1 ${
                            isDue ? (ledger.party_type === 'CUSTOMER' ? 'text-emerald-600' : 'text-rose-600') : 'text-gray-400'
                        }`}>
                            {formatCurrency(ledger.balance_due)}
                        </div>
                        <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">Balance</p>
                    </div>
                </div>

                {/* Bottom Row: Bill Details */}
                <div className="flex items-center justify-between pt-3 border-t border-gray-50">
                    <div className="flex items-center gap-4">
                        {ledger.latest_bill_number && (
                            <div className="flex items-center gap-1.5 text-gray-500">
                                <FileText size={14} className="text-gray-300" />
                                <span className="text-[11px] font-bold tracking-tight">#{ledger.latest_bill_number}</span>
                            </div>
                        )}
                        {ledger.latest_bill_amount && (
                            <div className="text-[11px] font-bold text-gray-500">
                                <span className="text-gray-300 uppercase text-[9px] mr-1">Bill Total:</span>
                                {formatCurrency(ledger.latest_bill_amount)}
                            </div>
                        )}
                    </div>
                    
                    <div className="flex items-center gap-2">
                        {isDue && (
                            <button 
                                onClick={(e) => {
                                    e.stopPropagation();
                                    onReminder(ledger);
                                }}
                                className="flex items-center gap-1.5 bg-green-50 text-green-700 px-3 py-1.5 rounded-xl text-xs font-black hover:bg-green-600 hover:text-white transition-all uppercase tracking-wider"
                            >
                                <MessageCircle size={13} />
                                Remind
                            </button>
                        )}
                        {isDue && (
                            <button 
                                onClick={(e) => {
                                    e.stopPropagation();
                                    onPay(ledger.id, ledger.balance_due);
                                }}
                                className="bg-indigo-50 text-indigo-600 px-4 py-1.5 rounded-xl text-xs font-black hover:bg-indigo-600 hover:text-white transition-all uppercase tracking-wider"
                            >
                                {ledger.party_type === 'CUSTOMER' ? 'Collect' : 'Pay'}
                            </button>
                        )}
                        <button className="p-2 text-gray-300 hover:text-gray-600 transition-colors">
                            <ChevronRight size={20} />
                        </button>
                    </div>
                </div>
            </div>
        </div>
    );
};

export default UdharDashboardPage;
