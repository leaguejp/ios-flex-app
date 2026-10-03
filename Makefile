ARCHS = arm64
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME ?= rootless
DEBUG = 0
FINALPACKAGE = 1
include $(THEOS)/makefiles/common.mk
# Current Xcode ld rejects the intent of Theos' obsolete duplicate-symbol suppression.
# Remove the option, preserving normal duplicate-symbol errors (do not suppress warnings).
_THEOS_TARGET_LDFLAGS := $(filter-out -multiply_defined suppress,$(_THEOS_TARGET_LDFLAGS))

APPLICATION_NAME = RuntimeAtlas AtlasTestTarget
RuntimeAtlas_FILES = controller/App.m controller/LXApplications.m controller/LXController.m controller/LXStore.m static/LXStaticAnalyzer.m core/macho.c core/encoding.c shared/LXTypes.m ui/LXBrowser.m shared/LXProtocol.m shared/LXChannel.m shared/LXAuth.m
RuntimeAtlas_FRAMEWORKS = UIKit Foundation
RuntimeAtlas_CFLAGS = -fobjc-arc -Wall -Wextra -Werror
RuntimeAtlas_RESOURCE_DIRS = controller/Resources
RuntimeAtlas_INSTALL_PATH = /Applications
AtlasTestTarget_FILES = testtarget/App.m testtarget/LXFixture.m
AtlasTestTarget_FRAMEWORKS = UIKit Foundation
AtlasTestTarget_CFLAGS = -fobjc-arc -Wall -Wextra -Werror
AtlasTestTarget_RESOURCE_DIRS = testtarget/Resources
AtlasTestTarget_INSTALL_PATH = /Applications

TWEAK_NAME = RuntimeAtlasAgent
RuntimeAtlasAgent_FILES = agent/Entry.m agent/LXAgent.m runtime/LXScanner.m static/LXStaticAnalyzer.m hook/LXHookEngine.m shared/LXChannel.m shared/LXProtocol.m shared/LXTypes.m shared/LXAuth.m core/encoding.c core/macho.c
RuntimeAtlasAgent_FRAMEWORKS = UIKit Foundation
RuntimeAtlasAgent_CFLAGS = -fobjc-arc -Wall -Wextra -Werror
hook/LXHookEngine.m_CFLAGS = -fno-objc-arc

include $(THEOS_MAKE_PATH)/application.mk
include $(THEOS_MAKE_PATH)/tweak.mk
