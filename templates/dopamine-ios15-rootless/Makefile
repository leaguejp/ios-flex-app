export THEOS_PACKAGE_SCHEME = rootless
export ARCHS = arm64 arm64e
export TARGET = iphone:clang:latest:15.5
export FINALPACKAGE = 1
export DEBUG = 0
export THEOS_PLATFORM_DEB_COMPRESSION_TYPE = gzip

include $(THEOS)/makefiles/common.mk
# Pinned Theos predates ld64's removal of this obsolete linker option.
_THEOS_TARGET_LDFLAGS := $(filter-out -multiply_defined suppress,$(_THEOS_TARGET_LDFLAGS))

TWEAK_NAME = ExampleTweak
ExampleTweak_FILES = Tweak.x
ExampleTweak_FRAMEWORKS = UIKit Foundation
ExampleTweak_EXTRA_FRAMEWORKS = Cephei
ExampleTweak_CFLAGS = -fobjc-arc -Wall -Wextra -Werror
include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
