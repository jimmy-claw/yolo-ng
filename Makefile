# yolo-ng Makefile

LGPM ?= lgpm
LOGOS_PROFILE ?= LogosAppNix
LOGOS_DATA_DIR ?= $(HOME)/.local/share/Logos/$(LOGOS_PROFILE)

.PHONY: build install-lgx clean

build:
	nix build .#lgx

install-lgx: build
	$(LGPM) install --file result/yolo-ng.lgx \
		--ui-plugins-dir $(LOGOS_DATA_DIR)/plugins \
		--modules-dir $(LOGOS_DATA_DIR)/modules

# Override profile: make install-lgx LOGOS_PROFILE=LogosApp
