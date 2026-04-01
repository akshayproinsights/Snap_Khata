import React, { useEffect, useRef, useCallback } from 'react';
import { useLocation } from 'react-router-dom';
import { useGlobalStatus } from '../contexts/GlobalStatusContext';
import { uploadAPI as salesAPI, reviewAPI } from '../services/api';
import { usePolling } from '../hooks/usePolling';

const SalesBackgroundPoller: React.FC = () => {
    const location = useLocation();
    const { setSalesStatus } = useGlobalStatus();
    const statsIntervalRef = useRef<any>(null);

    // Defined at component level to be reusable
    const fetchGlobalStats = useCallback(async () => {
        // PREVENT FLUCTUATION:
        // If an upload is in progress, we paused stats updates to keep the number stable.
        // The number should only update once the COMPLETION event is processed.
        if (localStorage.getItem('activeSalesTaskId')) {
            return;
        }

        try {
            // Fetch both dates and amounts data to ensure accurate counts matching Review Page
            const [datesData, amountsData] = await Promise.all([
                reviewAPI.getDates(),
                reviewAPI.getAmounts()
            ]);

            const allRecords = [...(datesData.records || []), ...(amountsData.records || [])];

            // Count unique receipt numbers by status
            const allReceiptNumbers = new Set<string>();
            allRecords.forEach(r => {
                if (r['Receipt Number']) allReceiptNumbers.add(r['Receipt Number']);
            });

            let pending = 0;
            let completed = 0;
            let duplicates = 0;

            allReceiptNumbers.forEach(receiptNum => {
                const receiptRecords = allRecords.filter(r => r['Receipt Number'] === receiptNum);

                // Normalize status
                const getStatus = (r: any) => (r['Verification Status'] || 'Pending').toLowerCase();

                const allDone = receiptRecords.every(r => getStatus(r) === 'done');
                const hasPending = receiptRecords.some(r => getStatus(r) === 'pending');
                const hasDuplicate = receiptRecords.some(r => getStatus(r) === 'duplicate receipt number');

                if (hasDuplicate) {
                    duplicates++;
                } else if (allDone) {
                    completed++;
                } else if (hasPending) {
                    pending++;
                }
            });

            setSalesStatus({
                reviewCount: pending + duplicates,
                syncCount: completed
            });
        } catch (error: any) {
            const status = error?.response?.status;
            // Stop spamming on rate limit or auth errors
            if (status === 429 || status === 401 || status === 403) {
                console.warn('[SalesPoller] Stats fetch stopped due to HTTP', status);
                if (statsIntervalRef.current) {
                    clearInterval(statsIntervalRef.current);
                    statsIntervalRef.current = null;
                }
                return;
            }
            console.error('Error fetching global sales stats:', error);
        }
    }, [setSalesStatus]);

    // 1. Poll for global stats (Review Count) independent of upload tasks
    useEffect(() => {
        // Fetch immediately on mount
        fetchGlobalStats();

        // Poll every 10 seconds to keep sidebar accurate
        statsIntervalRef.current = setInterval(fetchGlobalStats, 10000);

        return () => {
            if (statsIntervalRef.current) {
                clearInterval(statsIntervalRef.current);
                statsIntervalRef.current = null;
            }
        };
    }, [fetchGlobalStats]);

    // Build the polling function for the task status poller
    const taskPollFn = useCallback(async (): Promise<boolean> => {
        const activeTaskId = localStorage.getItem('activeSalesTaskId');

        // No task — signal done so the hook stops
        if (!activeTaskId) return true;

        const statusData = await salesAPI.getProcessStatus(activeTaskId);

        const total = statusData.progress?.total || 0;
        const processed = statusData.progress?.processed || 0;
        const failed = statusData.progress?.failed || 0;
        const remaining = Math.max(0, total - processed - failed);

        if (statusData.status === 'completed') {
            localStorage.removeItem('activeSalesTaskId');
            setSalesStatus({
                isUploading: false,
                processingCount: 0,
                totalProcessing: 0,
                isComplete: true
            });
            await fetchGlobalStats();
            return true; // Signal stop
        }

        if (statusData.status === 'failed') {
            setSalesStatus({
                isUploading: false,
                processingCount: 0,
                totalProcessing: 0,
                reviewCount: 0,
                syncCount: 0,
                isComplete: false
            });
            localStorage.removeItem('activeSalesTaskId');
            return true; // Signal stop
        }

        if (statusData.status === 'duplicate_detected') {
            setSalesStatus({
                isUploading: false,
                processingCount: 0,
                isComplete: false
            });
            // Don't stop — user needs to resolve duplicates, keep polling
            return false;
        }

        // Still processing
        setSalesStatus({
            isUploading: false,
            processingCount: remaining,
            totalProcessing: total,
            syncCount: processed,
            isComplete: false
        });
        return false;
    }, [setSalesStatus, fetchGlobalStats]);

    const handleFatalError = useCallback((statusCode: number) => {
        console.error(`[SalesPoller] ⛔ Fatal HTTP ${statusCode} — clearing task and resetting state.`);
        localStorage.removeItem('activeSalesTaskId');
        setSalesStatus({
            isUploading: false,
            processingCount: 0,
            totalProcessing: 0,
            isComplete: false
        });
    }, [setSalesStatus]);

    const handleMaxAttemptsReached = useCallback(() => {
        console.warn('[SalesPoller] ⛔ Max attempts reached — stopping. Task may still be running on server.');
        localStorage.removeItem('activeSalesTaskId');
        setSalesStatus({
            isUploading: false,
            processingCount: 0,
            totalProcessing: 0,
            isComplete: false
        });
    }, [setSalesStatus]);

    const { start: startTaskPoll, stop: stopTaskPoll } = usePolling({
        fn: taskPollFn,
        baseDelay: 2000,
        maxDelay: 30000,
        maxAttempts: 30,
        onFatalError: handleFatalError,
        onMaxAttemptsReached: handleMaxAttemptsReached,
    });

    // 2. Poll for active upload processing tasks
    useEffect(() => {
        // Don't poll task status if we are ON the upload page (the page handles its own polling)
        if (location.pathname === '/sales/upload') {
            stopTaskPoll();
            return;
        }

        const activeTaskId = localStorage.getItem('activeSalesTaskId');
        if (activeTaskId) {
            startTaskPoll();
        }

        return () => {
            stopTaskPoll();
        };
    }, [location.pathname, startTaskPoll, stopTaskPoll]);

    return null; // This component doesn't render anything
};

export default SalesBackgroundPoller;
