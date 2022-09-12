SHELL=/bin/bash

export TFLINT_LOG := "info"

.PHONY: test
test: test-all

.PHONY: test-all
test-all: test-shared test-blue test-green

.PHONY: test-shared
test-shared: format-shared init-shared validate-shared lint-shared plan-shared

.PHONY: test-blue
test-blue: format-blue init-blue validate-blue lint-blue plan-blue

.PHONY: test-green
test-green: format-green init-green validate-green lint-green plan-green


define FORMAT
	pushd ../../terraform/${1} \
	&& terraform fmt \
	&& popd

endef

.PHONY: format-shared
format-shared:
	$(call FORMAT,shared)

.PHONY: format-blue
format-blue:
	$(call FORMAT,blue)

.PHONY: format-green
format-green:
	$(call FORMAT,green)

define FORMAT-CHECK
	pushd ../../terraform/${1} \
	&& terraform fmt -check \
	&& popd

endef

.PHONY: format-check-shared
format-check-shared:
	$(call FORMAT-CHECK,shared)

.PHONY: format-check-blue
format-check-blue:
	$(call FORMAT-CHECK,blue)

.PHONY: format-check-green
format-check-green:
	$(call FORMAT-CHECK,green)


define INIT
	pushd ../fixtures/${1} \
	&& terraform init -upgrade -no-color \
	&& terraform fmt \
	&& popd

endef

.PHONY: init-shared
init-shared:
	$(call INIT,shared)

.PHONY: init-blue
init-blue:
	$(call INIT,blue)

.PHONY: init-green
init-green:
	$(call INIT,green)


define VALIDATE
	pushd ../fixtures/${1} \
	&& terraform validate -no-color \
	&& popd

endef

.PHONY: validate-shared
validate-shared:
	$(call VALIDATE,shared)

.PHONY: validate-blue
validate-blue:
	$(call VALIDATE,blue)

.PHONY: validate-green
validate-green:
	$(call VALIDATE,green)


define LINT
	tflint --init \
	&& pushd ../fixtures/${1} \
	&& tflint --config ../../integration/.tflint.hcl --module --var-file=integration.tfvars --no-color -f compact \
	&& popd

endef

.PHONY: lint-shared
lint-shared:
	$(call LINT,shared)

.PHONY: lint-blue
lint-blue:
	$(call LINT,blue)

.PHONY: lint-green
lint-green:
	$(call LINT,green)


define PLAN
	pushd ../fixtures/${1} \
	&& terraform plan -var-file=integration.tfvars -no-color \
	&& popd

endef

.PHONY: plan-shared
plan-shared:
	$(call PLAN,shared)

.PHONY: plan-blue
plan-blue:
	$(call PLAN,blue)

.PHONY: plan-green
plan-green:
	$(call PLAN,green)


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
	$(call CLEAN,shared)
