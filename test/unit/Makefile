SHELL=/bin/bash

.PHONY: test
test: prep-all test-all

.PHONY: test-all
test-all:
	go test -v

.PHONY: test-shared
test-shared:
	go test -v -run TestTerraformShared

.PHONY: test-blue
test-blue:
	go test -v -run TestTerraformBlue

.PHONY: test-green
test-green:
	go test -v -run TestTerraformGreen

.PHONY: prep
prep: prep-all

.PHONY: prep-all
prep-all: prep-shared prep-blue prep-green

.PHONY: prep-shared
prep-shared:
	pushd ../../terraform/shared \
	&& terraform fmt \
	&& popd \
	&& pushd ../fixtures/shared \
	&& terraform init -upgrade -backend=false \
	&& tflint --init \
	&& tflint --module --var-file=test.tfvars --loglevel=info \
	&& terraform validate \
	&& popd

.PHONY: prep-blue
prep-blue:
	pushd ../../terraform/blue \
	&& terraform fmt \
	&& popd \
	&& pushd ../fixtures/blue \
	&& terraform init -upgrade -backend=false \
	&& tflint --init \
	&& tflint --module --var-file=test.tfvars --loglevel=info \
	&& terraform validate \
	&& popd

.PHONY: prep-green
prep-green:
	pushd ../../terraform/green \
	&& terraform fmt \
	&& popd \
	&& pushd ../fixtures/green \
	&& terraform init -upgrade -backend=false \
	&& tflint --init \
	&& tflint --module --var-file=test.tfvars --loglevel=info \
	&& terraform validate \
	&& popd
