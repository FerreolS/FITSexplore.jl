SHELL := /bin/sh

EXE_NAME ?= fitsexplore
JULIAC_ENV ?= /tmp/juliac-env
BUNDLE_DIR ?= build-juliac
TRIM_MODE ?= safe
EXPERIMENTAL ?= 1

# Where to install the self-contained bundle and launcher symlink.
INSTALL_ROOT ?= $(HOME)/.julia/bundles/$(EXE_NAME)-bundle
BIN_DIR ?= $(HOME)/.julia/bin

.PHONY: help build install uninstall clean

help:
	@echo "Targets:"
	@echo "  make build      Build relocatable binary bundle with JuliaC"
	@echo "  make install    Copy bundle to $(INSTALL_ROOT) and symlink to $(BIN_DIR)/$(EXE_NAME)"
	@echo "  make uninstall  Remove installed symlink and bundle"
	@echo "  make clean      Remove local build bundle ($(BUNDLE_DIR))"

build:
	JULIAC_ENV='$(JULIAC_ENV)' \
	BUNDLE_DIR='$(BUNDLE_DIR)' \
	EXE_NAME='$(EXE_NAME)' \
	TRIM_MODE='$(TRIM_MODE)' \
	EXPERIMENTAL='$(EXPERIMENTAL)' \
	julia make.jl

install: build
	@mkdir -p '$(dir $(INSTALL_ROOT))'
	@mkdir -p '$(BIN_DIR)'
	@rm -rf '$(INSTALL_ROOT)'
	@cp -R '$(BUNDLE_DIR)' '$(INSTALL_ROOT)'
	@ln -snf '$(INSTALL_ROOT)/bin/$(EXE_NAME)' '$(BIN_DIR)/$(EXE_NAME)'
	@echo "Installed $(EXE_NAME) to $(INSTALL_ROOT)"
	@echo "Symlink: $(BIN_DIR)/$(EXE_NAME) -> $(INSTALL_ROOT)/bin/$(EXE_NAME)"

uninstall:
	@rm -f '$(BIN_DIR)/$(EXE_NAME)'
	@rm -rf '$(INSTALL_ROOT)'
	@echo "Removed $(EXE_NAME) from $(BIN_DIR) and $(INSTALL_ROOT)"

clean:
	@rm -rf '$(BUNDLE_DIR)'
	@echo "Removed $(BUNDLE_DIR)"
