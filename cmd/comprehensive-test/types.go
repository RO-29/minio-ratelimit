package main

import (
	"sync"
	"time"
)

// ServiceAccount represents a MinIO service account with credentials and group
type ServiceAccount struct {
	AccessKey string `json:"access_key"`
	SecretKey string `json:"secret_key"`
	Group     string `json:"group"`
}

// TestResult holds the results of a single test run
type TestResult struct {
	APIKey           string
	Group            string
	Method           string
	RequestsSent     int
	Success          int
	RateLimited      int
	Errors           int
	AvgLatencyMs     int64
	AuthMethod       string
	RateLimitGroup   string
	BurstHits        int
	MinuteHits       int
	HeaderCaptures   []ResponseHeaders
	RateLimitDetails RateLimitInfo
	ErrorDetails     map[string]int // Track error types
	ErrorExamples    []ErrorExample // Sample error messages
}

// ErrorExample represents a sample error for debugging
type ErrorExample struct {
	StatusCode int
	Error      string
	Timestamp  time.Time
	Method     string
}

// ResponseHeaders captures HTTP response headers for analysis
type ResponseHeaders struct {
	Timestamp  time.Time
	StatusCode int
	Headers    map[string]string
	LatencyMs  int64
}

// RateLimitInfo contains rate limiting information from headers
type RateLimitInfo struct {
	LimitPerSecond   int64
	LimitPerMinute   int64
	Limit            int64
	RemainingSecond  int64
	RemainingMinute  int64
	CurrentPerSecond int64
	CurrentPerMinute int64
	ResetTime        int64
}

// ProgressTracker tracks real-time test progress
type ProgressTracker struct {
	totalRequests  int64
	successCount   int64
	rateLimitCount int64
	errorCount     int64
	startTime      time.Time
	lastUpdate     time.Time
	mu             sync.Mutex
}

// TestSummary contains aggregated test results and analysis
type TestSummary struct {
	TotalTests        int
	Duration          time.Duration
	ByGroup           map[string]TestResult
	AuthMethods       map[string]int
	TotalRequests     int
	TotalSuccess      int
	TotalLimited      int
	TotalErrors       int
	RateLimitAnalysis map[string]RateLimitAnalysis
	BurstPatterns     map[string][]BurstEvent
	HeaderAnalysis    HeaderAnalysis
}

// RateLimitAnalysis provides insights into rate limiting behavior
type RateLimitAnalysis struct {
	Group          string
	EffectiveLimit int64
	ObservedBursts int
	AverageReset   time.Duration
	SuccessRate    float64
	ThrottleEvents []ThrottleEvent
}

// BurstEvent represents a burst of requests and their results
type BurstEvent struct {
	Timestamp    time.Time
	RequestCount int
	SuccessCount int
	Throttled    bool
}

// ThrottleEvent represents when a request was throttled
type ThrottleEvent struct {
	Timestamp     time.Time
	Group         string
	Method        string
	RemainingReqs int64
	ResetIn       time.Duration
}

// HeaderAnalysis provides analysis of HTTP response headers
type HeaderAnalysis struct {
	UniqueAuthMethods []string
	RateLimitHeaders  map[string]int64
	ResponsePatterns  map[int]int
	ErrorBreakdown    map[string]ErrorBreakdown
}

// ErrorBreakdown categorizes different types of errors
type ErrorBreakdown struct {
	StatusCode int
	Count      int
	Examples   []string
	IsExpected bool // Whether this error type is expected in testing
	Description string
}