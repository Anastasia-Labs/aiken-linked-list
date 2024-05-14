
.PHONY: help
help:
	@echo "Usage: make <target>"
	@echo
	@echo "Targets:"
	@echo "  help  -- show this help"
	@echo "  shell -- start a nix development shell"
	@echo "  build -- build the project"
	@echo "  test -- test the project"

.PHONY: shell
shell:
	nix shell github:aiken-lang/aiken#aiken

.PHONY: build
build:
	aiken build

.PHONY: test
test:
	aiken check
