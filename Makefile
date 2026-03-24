# yolo-ng Makefile

LGPM ?= lgpm
LOGOS_DATA_DIR ?= $(HOME)/.local/share/Logos/LogosAppNix

.PHONY: build install-lgx

build:
	nix build .#lgx-core --out-link result-core
	nix build .#lgx-ui --out-link result-ui

install-lgx: build
	$(LGPM) install --file result-core/yolo-ng-core.lgx \
		--modules-dir $(LOGOS_DATA_DIR)/modules
	$(LGPM) install --file result-ui/yolo-ng-ui.lgx \
		--ui-plugins-dir $(LOGOS_DATA_DIR)/plugins

# Override install dir: LOGOS_DATA_DIR=~/.local/share/Logos/LogosApp make install-lgx
