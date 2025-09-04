package main

import (
	"context"
	"fmt"
	"sync/atomic"
	"time"
)

// displayRealTimeProgress shows real-time test progress
func displayRealTimeProgress(ctx context.Context, progress *ProgressTracker) {
	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			progress.mu.Lock()
			total := atomic.LoadInt64(&progress.totalRequests)
			success := atomic.LoadInt64(&progress.successCount)
			throttled := atomic.LoadInt64(&progress.rateLimitCount)
			errors := atomic.LoadInt64(&progress.errorCount)
			elapsed := time.Since(progress.startTime)
			progress.mu.Unlock()

			if total > 0 {
				rps := float64(total) / elapsed.Seconds()
				successRate := float64(success) * 100 / float64(total)
				throttleRate := float64(throttled) * 100 / float64(total)

				fmt.Printf("\r⏱️  %02d:%02d | 📊 %d reqs (%.1f/sec) | ✅ %.1f%% success | 🚫 %.1f%% throttled | ❌ %d errors",
					int(elapsed.Minutes()), int(elapsed.Seconds())%60,
					total, rps, successRate, throttleRate, errors)
			}
		}
	}
}
