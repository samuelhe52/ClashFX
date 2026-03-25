WORKSPACE := ClashFX.xcworkspace
SCHEME := ClashFX
SDK := macosx
DERIVED_DATA ?= build_derived_data
CODE_SIGNING_ALLOWED ?= NO
DEBUG_APP := $(DERIVED_DATA)/Build/Products/Debug/ClashFX.app
RELEASE_APP := $(DERIVED_DATA)/Build/Products/Release/ClashFX.app

.PHONY: debug release build-debug build-release print-debug-app print-release-app run-debug run-release clean

debug: build-debug

release: build-release

build-debug:
	xcodebuild \
		-workspace $(WORKSPACE) \
		-scheme $(SCHEME) \
		-configuration Debug \
		-sdk $(SDK) \
		-derivedDataPath $(DERIVED_DATA) \
		build \
		CODE_SIGNING_ALLOWED=$(CODE_SIGNING_ALLOWED)

build-release:
	xcodebuild \
		-workspace $(WORKSPACE) \
		-scheme $(SCHEME) \
		-configuration Release \
		-sdk $(SDK) \
		-derivedDataPath $(DERIVED_DATA) \
		build \
		CODE_SIGNING_ALLOWED=$(CODE_SIGNING_ALLOWED)

print-debug-app:
	@echo $(DEBUG_APP)

print-release-app:
	@echo $(RELEASE_APP)

run-debug:
	"$(DEBUG_APP)/Contents/MacOS/ClashFX"

run-release:
	"$(RELEASE_APP)/Contents/MacOS/ClashFX"

clean:
	rm -rf $(DERIVED_DATA)
