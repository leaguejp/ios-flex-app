include $(THEOS)/makefiles/common.mk
_THEOS_TARGET_LDFLAGS := $(filter-out -multiply_defined suppress,$(_THEOS_TARGET_LDFLAGS))
BUNDLE_NAME = ExamplePrefs
ExamplePrefs_FILES = ETRootListController.m
ExamplePrefs_FRAMEWORKS = UIKit Foundation
ExamplePrefs_PRIVATE_FRAMEWORKS = Preferences
ExamplePrefs_LDFLAGS = -F$(CURDIR)/../sdk-stubs
ExamplePrefs_EXTRA_FRAMEWORKS = Cephei
ExamplePrefs_INSTALL_PATH = /Library/PreferenceBundles
ExamplePrefs_CFLAGS = -fobjc-arc -Wall -Wextra -Werror
include $(THEOS_MAKE_PATH)/bundle.mk
