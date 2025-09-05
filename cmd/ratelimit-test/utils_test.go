package main

import (
	"testing"
)

func TestUtilsCategorizeErrorEdgeCases(t *testing.T) {
	testCases := []struct {
		name       string
		errorMsg   string
		statusCode int
		expected   string
	}{
		{"Empty error, zero status", "", 0, "Other Error: "},
		{"Empty error, known status", "", 429, "Rate Limited (Expected - Testing Limits)"},
		{"Nil error equivalent", "", 0, "Other Error: "},
		{"Context canceled", "context canceled", 0, "Context Canceled (Expected - Test Timeout)"},
		{"Combined error", "timeout connection refused", 0, "Timeout (Expected - Heavy Load)"},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			result := categorizeError(tc.errorMsg, tc.statusCode)
			if result != tc.expected {
				t.Errorf("categorizeError(%q, %d) = %q, expected %q",
					tc.errorMsg, tc.statusCode, result, tc.expected)
			}
		})
	}
}

func TestMinFunction(t *testing.T) {
	testCases := []struct {
		name     string
		a        int
		b        int
		expected int
	}{
		{"A smaller than B", 5, 10, 5},
		{"B smaller than A", 15, 5, 5},
		{"Equal values", 7, 7, 7},
		{"Zero and positive", 0, 5, 0},
		{"Negative values", -3, -5, -5},
		{"Zero and negative", 0, -2, -2},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			result := min(tc.a, tc.b)
			if result != tc.expected {
				t.Errorf("min(%d, %d) = %d, expected %d",
					tc.a, tc.b, result, tc.expected)
			}
		})
	}
}
