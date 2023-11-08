SHELL=/bin/bash

TF_VERSION := 1.6.3

# Before running this test, you must:
# export GITHUB_TOKEN=your-token
# export GITHUB_USER=your-username

export TF_VAR_flux_git_user  := ${GITHUB_USER}
export TF_VAR_flux_git_token := ${GITHUB_TOKEN}

.PHONY: test
test: test-all

.PHONY: test-blue
test-blue:
	go test -v -run TestE2E -timeout 120m0s -scope blue -tf-version ${TF_VERSION}

.PHONY: test-green
test-green:
	go test -v -run TestE2E -timeout 120m0s -scope green -tf-version ${TF_VERSION}

.PHONY: test-all
test-all:
	go test -v -run TestE2E -timeout 120m0s -scope all -tf-version ${TF_VERSION}


define CLEAN
	pushd ../fixtures/${1} \
	&& terraform destroy -var-file=e2e.tfvars -auto-approve -no-color \
	&& popd

	pushd ../fixtures/${1} \
	&& rm -f terraform.tfstate \
	&& rm -f terraform.tfstate.backup \
	&& popd

endef

.PHONY: clean
clean: clean-all

.PHONY: clean-all
clean-all: clean-blue clean-green clean-shared

.PHONY: clean-shared
clean-shared:
	$(call CLEAN,shared)

.PHONY: clean-blue
clean-blue:
	$(call CLEAN,blue)

.PHONY: clean-green
clean-green:
	$(call CLEAN,green)
