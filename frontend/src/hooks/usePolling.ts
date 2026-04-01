import { useRef, useCallback } from 'react';

interface UsePollingOptions {
  /** The async function to call on each poll tick. Return true to stop polling early (task done). */
  fn: () => Promise<boolean | void>;
  /** Initial delay between polls in ms. Doubles on each error (exponential backoff). Default: 2000 */
  baseDelay?: number;
  /** Maximum delay cap in ms. Default: 30000 (30s) */
  maxDelay?: number;
  /**
   * Hard-kill the loop after this many attempts, regardless of outcome.
   * This is the ultimate safety net against runaway loops.
   * Default: 30
   */
  maxAttempts?: number;
  /**
   * Called when polling is killed due to a fatal HTTP error code.
   * statusCode will be the HTTP status (e.g. 429, 500, 502, 503).
   */
  onFatalError?: (statusCode: number) => void;
  /**
   * Called when the max attempts ceiling is hit.
   * Useful for showing the user a "timed out, please refresh" message.
   */
  onMaxAttemptsReached?: () => void;
}

/** HTTP status codes that should immediately stop polling — no retry. */
const FATAL_STATUS_CODES = new Set([429, 400, 401, 403, 404, 500, 502, 503, 504]);

/**
 * usePolling — A safe, self-limiting polling hook.
 *
 * Features:
 * - Exponential backoff on errors (baseDelay * 2^n, capped at maxDelay)
 * - Hard stops on fatal HTTP codes (429, 5xx, 403, 404)
 * - Absolute max-attempts ceiling (default 30) — the loop ALWAYS dies eventually
 * - Pauses polling when the browser tab is hidden; resumes on visibility
 * - Deduplication guard: only one poll loop can run at a time per hook instance
 */
export function usePolling({
  fn,
  baseDelay = 2000,
  maxDelay = 30000,
  maxAttempts = 30,
  onFatalError,
  onMaxAttemptsReached,
}: UsePollingOptions) {
  const timeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const attemptsRef = useRef(0);
  const isRunningRef = useRef(false);
  const currentDelayRef = useRef(baseDelay);
  const visibilityListenerRef = useRef<(() => void) | null>(null);

  const stop = useCallback(() => {
    isRunningRef.current = false;

    if (timeoutRef.current !== null) {
      clearTimeout(timeoutRef.current);
      timeoutRef.current = null;
    }

    // Remove the visibility listener if it exists
    if (visibilityListenerRef.current) {
      document.removeEventListener('visibilitychange', visibilityListenerRef.current);
      visibilityListenerRef.current = null;
    }

    console.log(`[usePolling] Stopped after ${attemptsRef.current} attempt(s).`);
  }, []);

  const scheduleNext = useCallback(
    (delay: number, scheduleNextFn: () => void) => {
      timeoutRef.current = setTimeout(() => {
        // If the tab is hidden, wait for it to become visible before polling
        if (document.visibilityState === 'hidden') {
          console.log('[usePolling] Tab is hidden — pausing until visible.');
          const onVisible = () => {
            if (isRunningRef.current) {
              document.removeEventListener('visibilitychange', onVisible);
              visibilityListenerRef.current = null;
              scheduleNextFn();
            }
          };
          visibilityListenerRef.current = onVisible;
          document.addEventListener('visibilitychange', onVisible);
          return;
        }

        scheduleNextFn();
      }, delay);
    },
    []
  );

  const tick = useCallback(async () => {
    if (!isRunningRef.current) return;

    // --- Safety net: max attempts ceiling ---
    if (attemptsRef.current >= maxAttempts) {
      console.warn(
        `[usePolling] ⛔ Max attempts (${maxAttempts}) reached. Killing poll loop.`
      );
      stop();
      onMaxAttemptsReached?.();
      return;
    }

    attemptsRef.current += 1;
    console.log(`[usePolling] Attempt ${attemptsRef.current}/${maxAttempts}`);

    try {
      const done = await fn();

      if (done === true || !isRunningRef.current) {
        // fn signalled completion, or stop() was called during await
        stop();
        return;
      }

      // Success — reset delay back to base for next tick
      currentDelayRef.current = baseDelay;
      scheduleNext(currentDelayRef.current, tick);
    } catch (error: any) {
      const statusCode: number | undefined = error?.response?.status;

      if (statusCode !== undefined && FATAL_STATUS_CODES.has(statusCode)) {
        console.error(
          `[usePolling] ⛔ Fatal HTTP ${statusCode} — stopping poll loop immediately.`
        );
        stop();
        onFatalError?.(statusCode);
        return;
      }

      // Non-fatal / network error — apply exponential backoff and retry
      const nextDelay = Math.min(currentDelayRef.current * 2, maxDelay);
      currentDelayRef.current = nextDelay;
      console.warn(
        `[usePolling] Non-fatal error (${statusCode ?? 'network'}). Backing off to ${nextDelay}ms.`,
        error?.message
      );
      scheduleNext(nextDelay, tick);
    }
  }, [fn, baseDelay, maxDelay, maxAttempts, onFatalError, onMaxAttemptsReached, stop, scheduleNext]);

  const start = useCallback(() => {
    if (isRunningRef.current) {
      console.warn('[usePolling] Already running — ignoring duplicate start().');
      return;
    }
    isRunningRef.current = true;
    attemptsRef.current = 0;
    currentDelayRef.current = baseDelay;
    console.log(`[usePolling] Started (maxAttempts=${maxAttempts}, baseDelay=${baseDelay}ms, maxDelay=${maxDelay}ms)`);
    // Fire first tick immediately (no initial delay)
    tick();
  }, [tick, baseDelay, maxAttempts, maxDelay]);

  return { start, stop };
}
