/**
 * Udhar (Credit) API client
 */
import apiClient from '../lib/api';

export interface Ledger {
    id: number;
    customer_name: string;
    balance_due: number;
    last_payment_date?: string;
    updated_at: string;
}

export interface Transaction {
    id: number;
    ledger_id: number;
    transaction_type: 'INVOICE' | 'PAYMENT';
    amount: number;
    receipt_number?: string;
    notes?: string;
    created_at: string;
    is_paid?: boolean;
}

export interface DashboardSummary {
    total_receivable: number;
    total_payable: number;
    // Add other fields if needed
}

export const udharAPI = {
    /**
     * Get dashboard summary
     */
    getSummary: async (): Promise<DashboardSummary> => {
        const response = await apiClient.get('/api/udhar/dashboard-summary');
        return response.data;
    },

    /**
     * Get all customer ledgers
     */
    getLedgers: async (): Promise<Ledger[]> => {
        const response = await apiClient.get('/api/udhar/ledgers');
        return response.data.data;
    },

    /**
     * Get transactions for a specific ledger
     */
    getTransactions: async (ledgerId: number): Promise<{ ledger: Ledger, data: Transaction[] }> => {
        const response = await apiClient.get(`/api/udhar/ledgers/${ledgerId}/transactions`);
        return response.data;
    },

    /**
     * Record a payment
     */
    recordPayment: async (ledgerId: number, amount: number, notes?: string): Promise<any> => {
        const response = await apiClient.post(`/api/udhar/ledgers/${ledgerId}/pay`, {
            amount,
            notes
        });
        return response.data;
    }
};
