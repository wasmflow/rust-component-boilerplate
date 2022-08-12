#####  Makefile Configuration  ######

.DEFAULT_GOAL:=all

ifdef OS
_OS := $(OS)
else
_OS := ""
endif

ifeq ($(_OS),Windows_NT)
SHELL := powershell.exe
MKDIR := mkdir -Force -p
.SHELLFLAGS := -NoProfile -Command
else
SHELL := bash
MKDIR := mkdir -p
.SHELLFLAGS := -eu -o pipefail -c
endif

MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

#####  Project Metadata  ######

# Name of the crate from Cargo.toml
CRATE_NAME:=$(shell wafl query -r -f Cargo.toml .package.name)

# CRATE_NAME with hyphens substituted with underscores
CRATE_FS_NAME:=$(subst -,_,$(CRATE_NAME))

# Version from Cargo.toml
CRATE_VERSION:=$(shell wafl query -r -f Cargo.toml .package.version)

WORKSPACE_ROOT:=$(shell cargo metadata --format-version 1 | wafl query -r '.workspace_root')

#####  Paths  #####

GENERATED_MODULE := ./src/components.rs # Wasmflow integration module

INTERFACE_JSON:=./interface.json

BUILD_DIR:=build/

#####  Wasmflow Commands  #####

# Override these commands if you have local development versions.
CMD_CODEGEN:=wasmflow-codegen
CMD_WAFL=wafl

#####  Flags/Options  #####

TARGET?=wasm32-unknown-unknown
REV?=0
STATEFUL=
WELLKNOWN=

##@ Tasks

.PHONY: all
all: build ## Make all targets

.PHONY: check
check: ## Run cargo check for the specified target
	cargo check --target=$(TARGET)

.PHONY: clean
clean:
	rm -f $(BUILD_DIR)/*
	rm -f $(GENERATED_MODULE)
	rm -f $(INTERFACE_JSON)

.PHONY: codegen
codegen: $(INTERFACE_JSON) $(GENERATED_MODULE) ## Automatically generate source files
	@$(MKDIR) ./src/components
	$(CMD_CODEGEN) rust component $(INTERFACE_JSON) --all $(STATEFUL) $(WELLKNOWN) -o ./src/components
	@cargo +nightly fmt

.PHONY: doc
doc: ## Generate documentation
	@echo Unimplemented

$(GENERATED_MODULE): $(INTERFACE_JSON) ## Generate the wasmflow integration code.
	$(CMD_CODEGEN) rust integration $(INTERFACE_JSON) $(STATEFUL) $(WELLKNOWN) -f -o $@

$(INTERFACE_JSON): ./schemas ## Create an interface.json from the project's schemas
	$(CMD_CODEGEN) json interface "$(CRATE_NAME)" ./schemas -o $@ -f

.PHONY: build
build: codegen ## Make and sign the wasm binary
	@$(MKDIR) $(BUILD_DIR)
	cargo build --target $(TARGET) --release
	cp $(WORKSPACE_ROOT)/target/$(TARGET)/release/$(CRATE_FS_NAME).wasm $(BUILD_DIR)/
	$(CMD_WAFL) wasm sign $(BUILD_DIR)/$(CRATE_FS_NAME).wasm $(INTERFACE_JSON) --ver=$(CRATE_VERSION) --rev=$(REV)
	@echo Signed artifacts located at: $$(ls $(BUILD_DIR)*signed*)

.PHONY: test
test: build ## Run tests
	cargo test

##@ Helpers

.PHONY: help
help:  ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<task>\033[0m\n"} /^[a-zA-Z0-9_\-.*]+:.*?##/ { printf "  \033[36m%-32s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

COLOR_GREEN:=\033[92m
COLOR_RED:=\033[91m
COLOR_OFF=\033[0m

.PHONY: debug
debug:  ## Print debug information
	@echo -e "$(COLOR_GREEN)Crate name:$(COLOR_OFF) '$(CRATE_NAME)'"
	@echo -e "$(COLOR_GREEN)Crate name (fs):$(COLOR_OFF) '$(CRATE_FS_NAME)'"
	@echo -e "$(COLOR_GREEN)Crate version:$(COLOR_OFF) '$(CRATE_VERSION)'"
	@echo -e "$(COLOR_GREEN)Workspace root:$(COLOR_OFF) '$(WORKSPACE_ROOT)'"
