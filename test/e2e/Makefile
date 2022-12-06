SHELL=/bin/bash

TF_VERSION := 1.3.6
FLUX_REPO_URL := https://github.com/torumakabe/aks-anti-dry-iac.git
# Make sure you pushed the branch under development if you modified /flux
FLUX_BRANCH := main

# Before running this test, you must:
# export GITHUB_TOKEN=your-token
# export GITHUB_USER=your-username

.PHONY: test
test: test-all

.PHONY: test-blue
test-blue:
	go test -v -run TestE2E -timeout 120m0s -scope blue -tf-version ${TF_VERSION} -flux-repo-url ${FLUX_REPO_URL} -flux-branch ${FLUX_BRANCH}

.PHONY: test-green
test-green:
	go test -v -run TestE2E -timeout 120m0s -scope green -tf-version ${TF_VERSION}  -flux-repo-url ${FLUX_REPO_URL} -flux-branch ${FLUX_BRANCH}

.PHONY: test-all
test-all:
	go test -v -run TestE2E -timeout 120m0s -scope all -tf-version ${TF_VERSION}  -flux-repo-url ${FLUX_REPO_URL} -flux-branch ${FLUX_BRANCH}


define CLEAN
	pushd ../fixtures/${1} \
	&& rm -f terraform.tfstate \
	&& rm -f terraform.tfstate.backup \
	&& popd

endef

.PHONY: clean
clean: clean-all

.PHONY: clean-all
clean-all: clean-shared clean-blue clean-green

.PHONY: clean-shared
clean-shared:
	$(call CLEAN,shared)

.PHONY: clean-blue
clean-blue:
	$(call CLEAN,blue)

.PHONY: clean-green
clean-green:
	$(call CLEAN,green)
