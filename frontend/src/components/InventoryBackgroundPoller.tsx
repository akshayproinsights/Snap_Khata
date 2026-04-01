import React, { useEffect, useCallback } from 'react';
import { useLocation } from 'react-router-dom';
import { useGlobalStatus } from '../contexts/GlobalStatusContext';
import { inventoryAPI } from '../services/inventoryApi';
import { usePolling } from '../hooks/usePolling';

const InventoryBackgroundPoller: React.FC = () => {
    const location = useLocation();
    const { setInventoryStatus } = useGlobalStatus();

    // Build the polling function
    const taskPollFn = useCallback(async (): Promise<boolean> => {
        const activeTaskId = localStorage.getItem('activeInventoryTaskId');

        // No task — signal done so the hook stops
        if (!activeTaskId) return true;

        const statusData = await inventoryAPI.getProcessStatus(activeTaskId);

        const total = statusData.progress?.total || 0;
        const processed = statusData.progress?.processed || 0;
        const remaining = Math.max(0, total - processed);

        if (statusData.status === 'completed') {
            setInventoryStatus({
                isUploading: false,
                processingCount: 0,
                totalProcessing: 0,
                syncCount: processed,
                isComplete: true
            });
            localStorage.removeItem('activeInventoryTaskId');
            return true; // Signal stop
        }

        if (statusData.status === 'failed') {
            setInventoryStatus({
                isUploading: false,
                processingCount: 0,
                totalProcessing: 0,
                reviewCount: 0,
                syncCount: 0,
                isComplete: false
            });
            localStorage.removeItem('activeInventoryTaskId');
            return true; // Signal stop
        }

        if (statusData.status === 'duplicate_detected') {
            setInventoryStatus({
                isUploading: false,
                processingCount: 0,
                isComplete: false
            });
            // Don't stop — user needs to resolve duplicates
            return false;
        }

        // Still processing
        setInventoryStatus({
            isUploading: false,
            processingCount: remaining,
            totalProcessing: total,
            syncCount: processed,
            isComplete: false
        });
        return false;
    }, [setInventoryStatus]);

    const handleFatalError = useCallback((statusCode: number) => {
        console.error(`[InventoryPoller] ⛔ Fatal HTTP ${statusCode} — clearing task and resetting state.`);
        localStorage.removeItem('activeInventoryTaskId');
        setInventoryStatus({
            isUploading: false,
            processingCount: 0,
            totalProcessing: 0,
            isComplete: false
        });
    }, [setInventoryStatus]);

    const handleMaxAttemptsReached = useCallback(() => {
        console.warn('[InventoryPoller] ⛔ Max attempts (30) reached — stopping. Task may still be running on server.');
        localStorage.removeItem('activeInventoryTaskId');
        setInventoryStatus({
            isUploading: false,
            processingCount: 0,
            totalProcessing: 0,
            isComplete: false
        });
    }, [setInventoryStatus]);

    const { start: startTaskPoll, stop: stopTaskPoll } = usePolling({
        fn: taskPollFn,
        baseDelay: 2000,
        maxDelay: 30000,
        maxAttempts: 30,
        onFatalError: handleFatalError,
        onMaxAttemptsReached: handleMaxAttemptsReached,
    });

    // Poll for active upload processing tasks
    useEffect(() => {
        // Don't poll task status if we are ON the upload page (that page handles its own polling)
        if (location.pathname === '/inventory/upload') {
            stopTaskPoll();
            return;
        }

        const activeTaskId = localStorage.getItem('activeInventoryTaskId');
        if (activeTaskId) {
            startTaskPoll();
        }

        return () => {
            stopTaskPoll();
        };
    }, [location.pathname, startTaskPoll, stopTaskPoll]);

    return null; // This component doesn't render anything
};

export default InventoryBackgroundPoller;
