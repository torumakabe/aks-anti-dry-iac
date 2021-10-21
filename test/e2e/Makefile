SHELL=/bin/bash

# Before running this test, you must:
# export GITHUB_TOKEN=your-token
# export GITHUB_USER=your-username

.PHONY: test
test: test-all

.PHONY: test-blue
test-blue:
	go test -v -run TestE2EBlue -timeout 60m0s

.PHONY: test-green
test-green:
	go test -v -run TestE2EGreen -timeout 60m0s

.PHONY: test-all
test-all:
	go test -v -run TestE2EAll -timeout 90m0s
