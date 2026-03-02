import React, { useEffect, useState } from 'react';
import { useParams, Navigate } from 'react-router-dom';
import { Download, Loader2 } from 'lucide-react';
import api from '../lib/api';

interface ReceiptData {
    id: string;
    image_url: string;
    customer_name?: string;
    total_amount?: number;
    paid_amount?: number;
    status: string;
    created_at: string;
    shop_name?: string;
}

const PublicReceiptPage: React.FC = () => {
    const { id } = useParams<{ id: string }>();
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [receipt, setReceipt] = useState<ReceiptData | null>(null);

    useEffect(() => {
        const fetchReceipt = async () => {
            if (!id) return;
            try {
                setLoading(true);
                // We will need to implement this public endpoint in the backend
                const response = await api.get(`/api/public/receipts/${id}`);
                setReceipt(response.data);
            } catch (err: any) {
                console.error('Error fetching public receipt:', err);
                setError('Failed to load receipt or receipt not found.');
            } finally {
                setLoading(false);
            }
        };

        fetchReceipt();
    }, [id]);

    if (!id) {
        return <Navigate to="/" replace />;
    }

    if (loading) {
        return (
            <div className="min-h-screen bg-gray-50 flex flex-col items-center justify-center p-4">
                <Loader2 className="h-10 w-10 text-indigo-600 animate-spin mb-4" />
                <h2 className="text-xl font-semibold text-gray-800">Loading receipt details...</h2>
            </div>
        );
    }

    if (error || !receipt) {
        return (
            <div className="min-h-screen bg-gray-50 flex flex-col items-center justify-center p-4 text-center">
                <div className="bg-white p-8 rounded-xl shadow-md max-w-md w-full">
                    <div className="h-16 w-16 bg-red-100 rounded-full flex items-center justify-center mx-auto mb-4">
                        <span className="text-red-600 text-2xl font-bold">!</span>
                    </div>
                    <h2 className="text-2xl font-bold text-gray-800 mb-2">Order Not Found</h2>
                    <p className="text-gray-600 mb-6">{error || 'The requested order link is invalid or unavailable.'}</p>
                    <button
                        onClick={() => window.location.reload()}
                        className="w-full bg-indigo-600 text-white font-medium py-2.5 px-4 rounded-lg hover:bg-indigo-700 transition-colors"
                    >
                        Try Again
                    </button>
                </div>
            </div>
        );
    }

    const handlePrint = () => {
        window.print();
    };

    const isPaid = receipt.status?.toLowerCase() === 'paid' ||
        receipt.status?.toLowerCase() === 'done' ||
        receipt.status?.toLowerCase() === 'confirmed';

    return (
        <div className="min-h-screen bg-gray-100 py-8 px-4 font-sans">
            <div className="max-w-2xl mx-auto">
                {/* Receipt Card */}
                <div className="bg-white rounded-xl shadow-lg border border-gray-200 overflow-hidden print:shadow-none print:border-none">
                    {/* Header */}
                    <div className="bg-white border-b border-gray-100 p-6 flex justify-between items-center sm:flex-row flex-col gap-4 text-center sm:text-left">
                        <div>
                            <h1 className="text-2xl font-black text-gray-900 uppercase tracking-tight">
                                {receipt.shop_name || 'Receipt Summary'}
                            </h1>
                            <p className="text-sm text-gray-500 mt-1">Order #{id}</p>
                        </div>

                        <div className="flex flex-col items-center sm:items-end">
                            <span className={`px-4 py-1.5 rounded-full text-sm font-bold tracking-wide ${isPaid ? 'bg-green-100 text-green-800 border border-green-200' : 'bg-yellow-100 text-yellow-800 border border-yellow-200'
                                }`}>
                                {isPaid ? 'PAID' : 'PENDING'}
                            </span>
                            <p className="text-xs text-gray-400 mt-2">
                                {new Date(receipt.created_at).toLocaleDateString('en-IN', {
                                    day: 'numeric', month: 'short', year: 'numeric'
                                })}
                            </p>
                        </div>
                    </div>

                    {/* Body Content */}
                    <div className="p-6">
                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-6 mb-8">
                            <div>
                                <h3 className="text-xs font-bold text-gray-400 uppercase tracking-wider mb-2">Billed To</h3>
                                <p className="text-base font-medium text-gray-900">{receipt.customer_name || 'Walk-in Customer'}</p>
                            </div>

                            {receipt.total_amount !== undefined && (
                                <div className="sm:text-right">
                                    <h3 className="text-xs font-bold text-gray-400 uppercase tracking-wider mb-2">Total Amount</h3>
                                    <p className="text-2xl font-black text-gray-900">
                                        ₹{receipt.total_amount.toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                                    </p>
                                </div>
                            )}
                        </div>

                        {/* Receipt Image Display */}
                        {receipt.image_url ? (
                            <div className="mt-6 border border-gray-200 rounded-xl overflow-hidden bg-gray-50 flex items-center justify-center p-2 shadow-inner">
                                <img
                                    src={receipt.image_url}
                                    alt={`Receipt ${id}`}
                                    className="max-w-full h-auto max-h-[600px] object-contain rounded-lg"
                                    onError={(e) => {
                                        const target = e.target as HTMLImageElement;
                                        target.src = 'https://placehold.co/600x400?text=Image+Not+Available';
                                    }}
                                />
                            </div>
                        ) : (
                            <div className="mt-6 border border-gray-200 border-dashed rounded-xl h-48 bg-gray-50 flex items-center justify-center">
                                <p className="text-gray-500 font-medium">Receipt image not loaded.</p>
                            </div>
                        )}

                        <div className="mt-8 pt-6 border-t border-gray-100 text-center print:hidden">
                            <p className="text-sm text-gray-500">Thank you for your business!</p>
                        </div>
                    </div>
                </div>

                {/* Floating Print Button - Hidden in Print Mode */}
                <div className="fixed bottom-6 right-6 print:hidden z-50">
                    <button
                        onClick={handlePrint}
                        className="flex items-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white px-5 py-3 rounded-full font-semibold shadow-lg hover:shadow-xl hover:-translate-y-0.5 transition-all"
                    >
                        <Download className="h-5 w-5" />
                        <span>Download / Print</span>
                    </button>
                </div>
            </div>
        </div>
    );
};

export default PublicReceiptPage;
