import React, { useState, useEffect, useMemo } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useOutletContext } from 'react-router-dom';
import { toast } from 'react-hot-toast';
import { udharAPI, Ledger } from '../services/udharAPI';
import { formatCurrency, formatActivityDate } from '../utils/dashboardHelpers';
import {
    Users,
    Truck,
    Search,
    MoreVertical,
    Plus,
    Filter,
    CheckCircle2,
    Clock,
    FileText,
    ChevronRight,
    ArrowUpRight,
    ArrowDownLeft
} from 'lucide-react';

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
                            />
                        ))
                    )}
                </div>
            </div>
        </div>
    );
};

interface PartyCardProps {
    ledger: Ledger;
    onPay: (id: number, amount: number) => void;
}

const PartyCard: React.FC<PartyCardProps> = ({ ledger, onPay }) => {
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
