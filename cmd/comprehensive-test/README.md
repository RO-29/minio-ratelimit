# MinIO Rate Limiting Comprehensive Test Suite - Modular Structure

This is a refactored version of the comprehensive rate limiting test tool, now organized into multiple well-structured modules for better maintainability and readability.

## File Structure

| File | Lines | Purpose |
|------|-------|---------|
| `main.go` | 77 | Main entry point and test execution flow |
| `config.go` | 77 | Command-line flag parsing and configuration loading |
| `types.go` | 130 | All type definitions and data structures |
| `accounts.go` | 71 | Account selection and grouping logic |
| `tests.go` | 841 | All test execution functions (MinIO, AWS S3, HTTP API, Burst, Premium stress tests) |
| `progress.go` | 38 | Real-time progress tracking and display |
| `reporting.go` | 344 | Report generation and comprehensive analysis |
| `export.go` | 47 | JSON export functionality |
| `utils.go` | 41 | Helper functions and error categorization |

## Key Improvements

### 1. **Separation of Concerns**
- **Configuration**: All flag parsing and config loading in `config.go`
- **Business Logic**: Test execution separated from reporting
- **Data Types**: Clean type definitions in dedicated file
- **Utilities**: Reusable helper functions isolated

### 2. **Enhanced Readability**
- **Reduced from**: Single 1589-line monolithic file
- **Organized into**: 9 focused modules with clear responsibilities
- **Largest module**: `tests.go` at 841 lines (still focused on test execution)

### 3. **Maintainability**
- **Easy to locate**: Specific functionality in logical files
- **Easy to modify**: Changes confined to relevant modules
- **Easy to test**: Individual components can be unit tested
- **Easy to extend**: New test types go in `tests.go`, new reports in `reporting.go`

### 4. **Preserved Functionality**
- ✅ All command-line flags and options
- ✅ All test types (MinIO, AWS S3, HTTP API, Burst, Premium stress)
- ✅ Real-time progress monitoring
- ✅ Comprehensive reporting with rate limit analysis
- ✅ JSON export functionality
- ✅ Error categorization and analysis
- ✅ Header capture and analysis
- ✅ Per-tier performance metrics

## Usage

The command-line interface remains exactly the same:

```bash
# Quick test
./comprehensive-test -duration=30s -accounts=2

# Stress test premium accounts
./comprehensive-test -stress-premium -duration=5m

# Export detailed results to JSON
./comprehensive-test -json -output=results.json

# Test specific tiers with custom settings
./comprehensive-test -tiers=premium -accounts=5 -duration=10m
```

## Module Dependencies

```
main.go
├── config.go (flag parsing, config loading)
├── accounts.go (account selection)
├── progress.go (real-time tracking)
├── tests.go (test execution)
│   ├── types.go (data structures)
│   └── utils.go (helper functions)
├── reporting.go (report generation)
│   ├── types.go
│   └── utils.go
└── export.go (JSON export)
    └── types.go
```

This modular structure makes the codebase much more maintainable while preserving all the enhanced features including command-line flags, JSON export, premium stress testing, per-tier error analysis, and comprehensive reporting.