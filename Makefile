# yolo-ng Makefile

LGPM ?= lgpm
LOGOS_DATA_DIR ?= $(HOME)/.local/share/Logos/LogosAppNix

.PHONY: build install-lgx

build:
	nix build .#lgx

install-lgx: build
	$(LGPM) install --file result/yolo-ng.lgx \
		--ui-plugins-dir $(LOGOS_DATA_DIR)/plugins \
		--modules-dir $(LOGOS_DATA_DIR)/modules

# Override install dir: LOGOS_DATA_DIR=~/.local/share/Logos/LogosApp make install-lgx
