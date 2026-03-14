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
	@echo "  make install    Build and install bundle to $(INSTALL_ROOT), symlink in $(BIN_DIR)"
	@echo "  make uninstall  Remove installed symlink and bundle"
	@echo "  make clean      Remove local build bundle ($(BUNDLE_DIR))"

define RUN_MAKEJL
	JULIAC_ENV='$(JULIAC_ENV)' \
	BUNDLE_DIR='$(BUNDLE_DIR)' \
	EXE_NAME='$(EXE_NAME)' \
	TRIM_MODE='$(TRIM_MODE)' \
	EXPERIMENTAL='$(EXPERIMENTAL)' \
	INSTALL_ROOT='$(INSTALL_ROOT)' \
	BIN_DIR='$(BIN_DIR)' \
	julia make.jl $(1)
endef

build:
	$(call RUN_MAKEJL,build)

install:
	$(call RUN_MAKEJL,install)

uninstall:
	$(call RUN_MAKEJL,uninstall)

clean:
	$(call RUN_MAKEJL,clean)
