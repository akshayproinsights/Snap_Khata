import React from 'react';
import { format } from 'date-fns';

export interface MaterialRequestPDFProps {
    id?: string;
    poNumber: string;
    date: Date | string;
    vendorName: string;
    senderName: string;
    senderPhone: string;
    shopName?: string;
    shopAddress?: string;
    shopPhone?: string;
    notes?: string;
    items: {
        partNumber: string;
        description: string;
        quantity: number;
    }[];
    pageIndex: number;
    totalPages: number;
    startItemNumber: number;
}

const MaterialRequestPDF: React.FC<MaterialRequestPDFProps> = ({
    id,
    poNumber,
    date,
    vendorName,
    senderName,
    senderPhone,
    shopName,
    shopAddress,
    shopPhone,
    notes,
    items,
    pageIndex,
    totalPages,
    startItemNumber
}) => {
    const formattedDate = date instanceof Date ? format(date, 'MMM dd, yyyy') : date;
    const isFirstPage = pageIndex === 0;
    const isLastPage = pageIndex === totalPages - 1;

    return (
        <>
            <style dangerouslySetInnerHTML={{
                __html: `
            @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');
            @page { size: A4; margin: 0; }
            @media print {
                body { -webkit-print-color-adjust: exact; }
            }
        `}} />

            <div
                id={id || "material-request-pdf"}
                className="bg-white text-gray-900 max-w-[210mm] mx-auto min-h-[297mm] flex flex-col relative shadow-2xl print:shadow-none font-sans"
                style={{ width: '210mm', fontFamily: "'Inter', sans-serif" }}
            >
                {/* 1. Sleek Header Section */}
                <div className="px-10 pt-16 pb-8">
                    <div className="flex justify-between items-start">
                        {/* Top Left: Clean Brand */}
                        <div className="flex flex-col max-w-[60%]">
                            <h1 className="text-3xl font-bold text-gray-900 tracking-tight mb-2">
                                {shopName || 'NEHA AUTO STORES'}
                            </h1>
                            <p className="text-sm text-gray-500 leading-relaxed max-w-[85%] whitespace-pre-wrap">
                                {shopAddress || '5, Shri Datta nagar, Opp. Yogeshwari Mahavidyalaya,\nAmbajogai - Dist. Beed 431517'}
                            </p>
                        </div>

                        {/* Top Right: Title & Meta aligned right to look premium */}
                        <div className="flex flex-col items-end min-w-[35%]">
                            <h2 className="text-2xl font-semibold text-gray-300 uppercase tracking-widest mb-6">
                                Material Request
                            </h2>
                            <div className="text-right space-y-2">
                                <div className="flex justify-end gap-6">
                                    <span className="text-sm text-gray-500">PO Number</span>
                                    <span className="text-sm font-semibold text-gray-900 w-32">{poNumber}</span>
                                </div>
                                <div className="flex justify-end gap-6">
                                    <span className="text-sm text-gray-500">Date</span>
                                    <span className="text-sm font-semibold text-gray-900 w-32">{formattedDate}</span>
                                </div>
                                <div className="flex justify-end gap-6">
                                    <span className="text-sm text-gray-500">Page</span>
                                    <span className="text-sm font-semibold text-gray-900 w-32">{pageIndex + 1} of {totalPages}</span>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                {/* 2. Professional Contact Info Layout */}
                {isFirstPage && (
                    <div className="px-10 py-6">
                        <div className="flex border-y border-gray-200 py-6">
                            {/* Left: Request To */}
                            <div className="w-1/2 pr-6">
                                <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2">Request To (Vendor)</p>
                                <p className="text-lg font-medium text-gray-900">{vendorName}</p>
                            </div>
                            {/* Right: Site Contact */}
                            <div className="w-1/2 pl-6 border-l border-gray-200">
                                <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2">Site Contact</p>
                                <div className="flex flex-col">
                                    <span className="text-lg font-medium text-gray-900">{senderName || 'User Name'}</span>
                                    <span className="text-sm text-gray-500 mt-1">{senderPhone || shopPhone || ''}</span>
                                </div>
                            </div>
                        </div>
                    </div>
                )}

                {/* 3. Sleek Table Design */}
                <div className="px-10 mt-4 mb-auto">
                    <table className="w-full border-collapse">
                        <thead>
                            <tr className="border-b-2 border-gray-900">
                                <th className="py-3 px-2 text-center w-12 text-xs font-semibold text-gray-500 uppercase tracking-wider">#</th>
                                <th className="py-3 px-2 text-left w-40 text-xs font-semibold text-gray-500 uppercase tracking-wider">Part Number</th>
                                <th className="py-3 px-2 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Description</th>
                                <th className="py-3 px-2 text-right w-24 text-xs font-semibold text-gray-500 uppercase tracking-wider">Qty</th>
                            </tr>
                        </thead>
                        <tbody>
                            {items.map((item, index) => (
                                <tr key={index} className="border-b border-gray-100 hover:bg-gray-50">
                                    <td className="py-4 px-2 text-center text-gray-400 text-sm">
                                        {startItemNumber + index}
                                    </td>
                                    <td className="py-4 px-2 text-left font-mono text-sm font-medium text-gray-700">
                                        {item.partNumber}
                                    </td>
                                    <td className="py-4 px-2 text-left text-sm text-gray-800">
                                        {item.description}
                                    </td>
                                    <td className="py-4 px-2 text-right">
                                        <span className="text-base font-semibold text-gray-900">{item.quantity}</span>
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>

                {/* 4. Minimalist Footer */}
                {isLastPage ? (
                    <div className="px-10 pb-12 mt-12">
                        {/* Notes Section - Clean & subtle */}
                        {notes && notes.trim() !== "" && (
                            <div className="bg-gray-50 rounded-md p-4 mb-8">
                                <p className="text-sm text-gray-600 italic">
                                    <span className="font-semibold not-italic text-gray-700">Note: </span>
                                    {notes}
                                </p>
                            </div>
                        )}

                        {/* Signature & Watermark Footer */}
                        <div className="flex justify-between items-end pt-8">
                            <div className="text-left w-1/2">
                                <p className="text-[11px] text-gray-400 mb-1">This is a digitally verified request and does not require a signature.</p>
                                <p className="text-[11px] text-gray-400">
                                    Powered by <span className="font-semibold text-gray-600">SnapKhata</span>
                                </p>
                            </div>

                            {/* User Name Signature Line */}
                            <div className="flex flex-col items-center justify-end w-48">
                                <div className="w-full h-px bg-gray-300 mb-2"></div>
                                <p className="text-[11px] font-medium text-gray-500 uppercase tracking-widest text-center">User Name</p>
                            </div>
                        </div>
                    </div>
                ) : (
                    <div className="px-10 pb-8 mt-4 text-center">
                        <p className="text-sm text-gray-400 italic">Continued on next page...</p>
                    </div>
                )}
            </div>
        </>
    );
};

export default MaterialRequestPDF;
