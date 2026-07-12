CONFIGURATION ?= Debug
SOURCE_PACKAGES_DIR ?=

BUILD_ENV = CONFIGURATION=$(CONFIGURATION)
ifneq ($(strip $(SOURCE_PACKAGES_DIR)),)
BUILD_ENV += SOURCE_PACKAGES_DIR="$(SOURCE_PACKAGES_DIR)"
endif

.PHONY: debug release build run verify print-app clean

debug: CONFIGURATION=Debug
debug: build

release: CONFIGURATION=Release
release: build

build:
	$(BUILD_ENV) ./script/build_and_run.sh build

run:
	$(BUILD_ENV) ./script/build_and_run.sh run

verify:
	$(BUILD_ENV) ./script/build_and_run.sh verify

print-app:
	@echo "$(CURDIR)/build_derived_data/Build/Products/$(CONFIGURATION)/ClashFX.app"

clean:
	rm -rf build_derived_data
