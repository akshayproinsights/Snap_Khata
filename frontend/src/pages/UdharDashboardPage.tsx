import React, { useState, useEffect } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useOutletContext } from 'react-router-dom';
import { toast } from 'react-hot-toast';
import { udharAPI } from '../services/udharAPI';
import { formatCurrency } from '../utils/dashboardHelpers';
import {
    Users,
    Truck,
    Search,
    MoreVertical,
    Plus,
    Filter,
    CheckCircle2
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
    const { data: ledgers, isLoading: ledgersLoading, refetch: refetchLedgers } = useQuery({
        queryKey: ['customerLedgers'],
        queryFn: udharAPI.getLedgers,
        staleTime: 0,
    });

    // Auto-refresh every 30 seconds
    useEffect(() => {
        const interval = setInterval(() => {
            refetchSummary();
            refetchLedgers();
        }, 30000);

        return () => clearInterval(interval);
    }, [refetchSummary, refetchLedgers]);

    // Mutations
    const recordPaymentMutation = useMutation({
        mutationFn: ({ ledgerId, amount }: { ledgerId: number, amount: number }) => 
            udharAPI.recordPayment(ledgerId, amount, "Full payment"),
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['customerLedgers'] });
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
    const filteredLedgers = (ledgers || []).filter(ledger => {
        // Search filter
        const matchesSearch = ledger.customer_name.toLowerCase().includes(searchTerm.toLowerCase());
        
        // Paid/Hidden filter
        // If showPaidBills is false, hide ledgers with 0 balance
        const isPaid = ledger.balance_due <= 0;
        const matchesPaidFilter = showPaidBills || !isPaid;
        
        return matchesSearch && matchesPaidFilter;
    });

    // Set header actions
    useEffect(() => {
        setHeaderActions(
            <div className="flex items-center gap-2">
                <button className="flex items-center gap-2 bg-indigo-600 text-white px-4 py-2 rounded-lg hover:bg-indigo-700 transition shadow-sm font-medium">
                    <Plus size={18} />
                    New Khata Entry
                </button>
            </div>
        );
    }, [setHeaderActions]);

    return (
        <div className="max-w-4xl mx-auto space-y-6">
            {/* Credit Summary Cards - Horizontal Style like Dashboard */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {/* TO PAY (Payable) - RED */}
                <div className="bg-white rounded-lg shadow-sm border border-red-200 hover:shadow-md transition-all duration-300 h-[90px]">
                    <div className="flex items-center h-full px-4 py-2.5 gap-4">
                        <div className="bg-red-100 text-red-600 w-12 h-12 rounded-lg flex items-center justify-center flex-shrink-0">
                            <Truck size={24} />
                        </div>
                        <div className="flex-1 min-w-0">
                            <h3 className="text-[11px] font-bold text-gray-500 uppercase tracking-wider mb-1 leading-tight">
                                To Pay
                            </h3>
                            <p className="text-3xl font-bold text-red-500 tabular-nums leading-none">
                                {summaryLoading ? '...' : formatCurrency(summary?.total_payable || 0)}
                            </p>
                        </div>
                    </div>
                </div>
                
                {/* TO COLLECT (Receivable) - GREEN */}
                <div className="bg-white rounded-lg shadow-sm border border-green-200 hover:shadow-md transition-all duration-300 h-[90px]">
                    <div className="flex items-center h-full px-4 py-2.5 gap-4">
                        <div className="bg-green-100 text-green-600 w-12 h-12 rounded-lg flex items-center justify-center flex-shrink-0">
                            <Users size={24} />
                        </div>
                        <div className="flex-1 min-w-0">
                            <h3 className="text-[11px] font-bold text-gray-500 uppercase tracking-wider mb-1 leading-tight">
                                To Collect
                            </h3>
                            <p className="text-3xl font-bold text-green-600 tabular-nums leading-none">
                                {summaryLoading ? '...' : formatCurrency(summary?.total_receivable || 0)}
                            </p>
                        </div>
                    </div>
                </div>
            </div>

            {/* Main Content Area */}
            <div className="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden flex flex-col min-h-[500px]">
                {/* Tabs */}
                <div className="flex border-b border-gray-100">
                    <button 
                        onClick={() => setActiveTab('customers')}
                        className={`flex-1 py-4 font-semibold text-sm transition-all relative ${
                            activeTab === 'customers' ? 'text-blue-600' : 'text-gray-500 hover:text-gray-700'
                        }`}
                    >
                        <div className="flex items-center justify-center gap-2">
                            <Users size={18} />
                            Customers
                        </div>
                        {activeTab === 'customers' && (
                            <div className="absolute bottom-0 left-0 right-0 h-1 bg-blue-600 rounded-t-full" />
                        )}
                    </button>
                    <button 
                        onClick={() => setActiveTab('suppliers')}
                        className={`flex-1 py-4 font-semibold text-sm transition-all relative ${
                            activeTab === 'suppliers' ? 'text-blue-600' : 'text-gray-500 hover:text-gray-700'
                        }`}
                    >
                        <div className="flex items-center justify-center gap-2">
                            <Truck size={18} />
                            Suppliers
                        </div>
                        {activeTab === 'suppliers' && (
                            <div className="absolute bottom-0 left-0 right-0 h-1 bg-blue-600 rounded-t-full" />
                        )}
                    </button>
                </div>

                {/* Filters Row */}
                <div className="p-4 border-b border-gray-100 space-y-4">
                    {/* Show Paid Bills Toggle - Prominent for SMB Owners */}
                    <div className="flex items-center justify-between bg-blue-50/50 p-3 rounded-xl border border-blue-100">
                        <div className="flex items-center gap-3">
                            <div className="bg-blue-100 p-2 rounded-lg text-blue-600">
                                <Filter size={18} />
                            </div>
                            <div>
                                <h3 className="text-sm font-bold text-gray-900 leading-tight">Show Paid Bills</h3>
                                <p className="text-xs text-gray-500">View Khata with zero balance</p>
                            </div>
                        </div>
                        <label className="relative inline-flex items-center cursor-pointer">
                            <input 
                                type="checkbox" 
                                className="sr-only peer" 
                                checked={showPaidBills}
                                onChange={(e) => setShowPaidBills(e.target.checked)}
                            />
                            <div className="w-11 h-6 bg-gray-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
                        </label>
                    </div>

                    {/* Search Bar */}
                    <div className="flex gap-2">
                        <div className="relative flex-1">
                            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
                            <input 
                                type="text"
                                placeholder="Search Khata Name..."
                                value={searchTerm}
                                onChange={(e) => setSearchTerm(e.target.value)}
                                className="w-full pl-10 pr-4 py-2.5 bg-gray-50 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 text-sm transition-all"
                            />
                        </div>
                        <button className="p-2.5 bg-gray-50 border border-gray-200 rounded-xl text-gray-600 hover:bg-gray-100 transition-colors">
                            <Filter size={18} />
                        </button>
                    </div>
                </div>

                {/* Ledger List */}
                <div className="flex-1 overflow-auto bg-gray-50/30 p-4">
                    {ledgersLoading ? (
                        <div className="flex flex-col items-center justify-center py-20 space-y-3">
                            <div className="w-8 h-8 border-4 border-blue-100 border-t-blue-600 rounded-full animate-spin" />
                            <p className="text-sm text-gray-500 font-medium">Loading Khata entries...</p>
                        </div>
                    ) : filteredLedgers.length === 0 ? (
                        <div className="flex flex-col items-center justify-center py-20 text-center px-6">
                            <div className="bg-gray-100 p-4 rounded-full text-gray-400 mb-4">
                                <Users size={32} />
                            </div>
                            <h3 className="text-lg font-bold text-gray-900 mb-1">No Khata Found</h3>
                            <p className="text-sm text-gray-500 max-w-[250px]">
                                {searchTerm 
                                    ? `No Khata matching "${searchTerm}"`
                                    : showPaidBills 
                                        ? "You haven't added any Khata entries yet."
                                        : "All your bills are paid! Turn on 'Show Paid Bills' to see history."
                                }
                            </p>
                        </div>
                    ) : (
                        <div className="space-y-3">
                            {filteredLedgers.map((ledger) => (
                                <div 
                                    key={ledger.id}
                                    className={`bg-white p-4 rounded-xl border border-gray-100 shadow-sm hover:border-blue-200 transition-all cursor-pointer group flex items-center justify-between ${
                                        ledger.balance_due <= 0 ? 'opacity-70 bg-gray-50/50' : ''
                                    }`}
                                >
                                    <div className="flex items-center gap-4">
                                        <div className={`w-12 h-12 rounded-full flex items-center justify-center text-lg font-bold ${
                                            ledger.balance_due <= 0 
                                                ? 'bg-gray-100 text-gray-500' 
                                                : 'bg-blue-50 text-blue-600'
                                        }`}>
                                            {ledger.customer_name.charAt(0).toUpperCase()}
                                        </div>
                                        <div>
                                            <h4 className="font-bold text-gray-900 group-hover:text-blue-600 transition-colors">
                                                {ledger.customer_name}
                                            </h4>
                                            <div className="flex items-center gap-1.5 text-xs text-gray-500 mt-0.5">
                                                {ledger.balance_due <= 0 ? (
                                                    <span className="flex items-center gap-1 text-green-600 font-bold">
                                                        <CheckCircle2 size={12} />
                                                        All Paid
                                                    </span>
                                                ) : (
                                                    <span>No payments yet</span>
                                                )}
                                                <span className="text-gray-300">•</span>
                                                <span>Just now</span>
                                            </div>
                                        </div>
                                    </div>
                                    
                                    <div className="flex items-center gap-4">
                                        <div className="text-right">
                                            <div className={`text-lg font-bold ${
                                                ledger.balance_due <= 0 ? 'text-green-600' : 'text-green-600'
                                            }`}>
                                                {formatCurrency(ledger.balance_due)}
                                            </div>
                                            <div className="text-[10px] uppercase tracking-wider font-bold text-gray-400">
                                                You will get
                                            </div>
                                        </div>
                                        
                                        {ledger.balance_due > 0 && (
                                            <button 
                                                onClick={(e) => {
                                                    e.stopPropagation();
                                                    handleRecordPayment(ledger.id, ledger.balance_due);
                                                }}
                                                disabled={recordPaymentMutation.isPending}
                                                className="bg-green-100 text-green-700 px-3 py-1.5 rounded-lg text-xs font-bold hover:bg-green-200 transition-colors disabled:opacity-50"
                                            >
                                                {recordPaymentMutation.isPending ? '...' : 'PAY'}
                                            </button>
                                        )}
                                        
                                        <button className="p-1 text-gray-400 hover:text-gray-600">
                                            <MoreVertical size={20} />
                                        </button>
                                    </div>
                                </div>
                            ))}
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
};

export default UdharDashboardPage;
