MODULES := modules/iam-user modules/iam-role modules/iam-policy modules/iam-group
COMPONENTS := live/_components/iam-users live/_components/iam-roles live/_components/iam-policies live/_components/iam-groups live/_components/iam-account

.PHONY: help test validate fmt fmt-check tf-init tf-validate tf-test check clean new-request

help:
	@echo "targets:"
	@echo "  test        - run the Python guardrail/changed-target test suite"
	@echo "  validate    - validate every request under requests/ against guardrails"
	@echo "  fmt         - terraform fmt + terragrunt hclfmt (writes changes)"
	@echo "  fmt-check   - same, but check-only (what CI runs)"
	@echo "  tf-validate - terraform validate for every module + aggregator"
	@echo "  tf-test     - terraform test (mock provider) for every module"
	@echo "  check       - validate + test + fmt-check + tf-validate + tf-test"
	@echo "  clean       - remove .terraform/.terragrunt-cache/__pycache__ artifacts"
	@echo "  new-request - scaffold a new request.yaml (see .claude/skills/new-iam-request)"
	@echo "                usage: make new-request COMPONENT=roles ENVIRONMENT=prod ACCOUNT_ID=999999999999 NAME=my-role"

test:
	python3 -m unittest discover -s tests -v

validate:
	python3 scripts/validate_requests.py

fmt:
	terraform fmt -recursive
	terragrunt hclfmt --working-dir=.

fmt-check:
	terraform fmt -check -recursive
	terragrunt hclfmt --check --working-dir=.

tf-init:
	@for d in $(MODULES) $(COMPONENTS); do \
		echo "=== init $$d ==="; \
		(cd $$d && terraform init -input=false -backend=false -upgrade=false) || exit 1; \
	done

tf-validate: tf-init
	@for d in $(MODULES) $(COMPONENTS); do \
		echo "=== validate $$d ==="; \
		(cd $$d && terraform validate) || exit 1; \
	done

tf-test: tf-init
	@for d in $(MODULES); do \
		echo "=== test $$d ==="; \
		(cd $$d && terraform test) || exit 1; \
	done

check: validate test fmt-check tf-validate tf-test

clean:
	find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".terragrunt-cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -name "terragrunt_rendered.json" -delete
	find . -name ".terraform.lock.hcl" -delete

new-request:
	@test -n "$(COMPONENT)" || (echo "COMPONENT is required (users|roles|policies|groups)"; exit 1)
	@test -n "$(ENVIRONMENT)" || (echo "ENVIRONMENT is required (prod|dev)"; exit 1)
	@test -n "$(ACCOUNT_ID)" || (echo "ACCOUNT_ID is required (12 digits)"; exit 1)
	@test -n "$(NAME)" || (echo "NAME is required"; exit 1)
	python3 scripts/scaffold_request.py --component $(COMPONENT) --environment $(ENVIRONMENT) --account-id $(ACCOUNT_ID) --name $(NAME)
