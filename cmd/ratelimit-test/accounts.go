package main

// Account selection logic for test execution

// selectTestAccounts selects accounts for testing (legacy function)
func selectTestAccounts(all []ServiceAccount, perGroup int) []ServiceAccount {
	groups := map[string][]ServiceAccount{
		"premium":  {},
		"standard": {},
		"basic":    {},
	}

	// Group accounts
	for _, acc := range all {
		groups[acc.Group] = append(groups[acc.Group], acc)
	}

	var selected []ServiceAccount
	for _, accounts := range groups {
		count := perGroup
		if len(accounts) < count {
			count = len(accounts)
		}
		for i := 0; i < count; i++ {
			selected = append(selected, accounts[i])
		}
	}

	return selected
}

// selectTestAccountsForConfig selects accounts based on test configuration
func selectTestAccountsForConfig(all []ServiceAccount, config TestConfig) []ServiceAccount {
	groups := map[string][]ServiceAccount{
		"premium":  {},
		"standard": {},
		"basic":    {},
	}

	// Group accounts by tier
	for _, acc := range all {
		groups[acc.Group] = append(groups[acc.Group], acc)
	}

	var selected []ServiceAccount
	for _, targetTier := range config.TargetTiers {
		if accounts, exists := groups[targetTier]; exists {
			count := config.AccountsPerTier
			if config.StressPremium && targetTier == "premium" {
				// Use more accounts for premium stress testing
				count = min(len(accounts), config.AccountsPerTier*2)
			}
			if len(accounts) < count {
				count = len(accounts)
			}
			for i := 0; i < count; i++ {
				selected = append(selected, accounts[i])
			}
		}
	}

	return selected
}

// countByGroup returns a count of accounts by group for reporting
func countByGroup(accounts []ServiceAccount) map[string]int {
	counts := map[string]int{}
	for _, acc := range accounts {
		counts[acc.Group]++
	}
	return counts
}
