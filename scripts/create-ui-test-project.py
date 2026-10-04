"""Generate an independent XCUITest runner for the already-installed Theos apps.

No provisioning/signing secrets, extra package manager or App Store target required.
The generated project is build output and never committed.
"""
from pathlib import Path
import json

root = Path(__file__).resolve().parent.parent
project = root / 'build/LaunchWorkflow.xcodeproj'
project.mkdir(parents=True, exist_ok=True)
source = json.dumps(str(root / 'tests/launch_ui_test.m'))
ids = {name: f'{index:024X}' for index, name in enumerate(
    ['project','main','products','target','source','product','buildfile','sources',
     'frameworks','resources','projectlist','targetlist','projectdebug','projectrelease',
     'targetdebug','targetrelease'], 1)}
i = ids
objects = [
 f'{i["project"]} = {{isa = PBXProject; attributes = {{LastUpgradeCheck = 1600;}}; buildConfigurationList = {i["projectlist"]}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; knownRegions = (en, Base); mainGroup = {i["main"]}; productRefGroup = {i["products"]}; projectDirPath = ""; projectRoot = ""; targets = ({i["target"]});}};',
 f'{i["main"]} = {{isa = PBXGroup; children = ({i["source"]}, {i["products"]}); sourceTree = "<group>";}};',
 f'{i["products"]} = {{isa = PBXGroup; children = ({i["product"]}); name = Products; sourceTree = "<group>";}};',
 f'{i["source"]} = {{isa = PBXFileReference; lastKnownFileType = sourcecode.c.objc; path = {source}; sourceTree = "<absolute>";}};',
 f'{i["product"]} = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = AtlasLaunchUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;}};',
 f'{i["buildfile"]} = {{isa = PBXBuildFile; fileRef = {i["source"]};}};',
 f'{i["sources"]} = {{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({i["buildfile"]}); runOnlyForDeploymentPostprocessing = 0;}};',
 f'{i["frameworks"]} = {{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;}};',
 f'{i["resources"]} = {{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;}};',
 f'{i["target"]} = {{isa = PBXNativeTarget; buildConfigurationList = {i["targetlist"]}; buildPhases = ({i["sources"]}, {i["frameworks"]}, {i["resources"]}); buildRules = (); dependencies = (); name = AtlasLaunchUITests; productName = AtlasLaunchUITests; productReference = {i["product"]}; productType = "com.apple.product-type.bundle.ui-testing";}};',
]
project_settings = 'CLANG_ENABLE_MODULES = YES; CLANG_ENABLE_OBJC_ARC = YES; SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 15.0;'
target_settings = '''PRODUCT_BUNDLE_IDENTIFIER = jp.league.runtimeatlas.uitests;
PRODUCT_NAME = "$(TARGET_NAME)"; GENERATE_INFOPLIST_FILE = YES;
CLANG_ENABLE_OBJC_ARC = YES; CLANG_ENABLE_MODULES = YES;
CODE_SIGNING_ALLOWED = NO; TARGETED_DEVICE_FAMILY = 1;
SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
FRAMEWORK_SEARCH_PATHS = ("$(inherited)", "$(PLATFORM_DIR)/Developer/Library/Frameworks");
OTHER_LDFLAGS = ("$(inherited)", "-framework", XCTest);
GCC_WARN_INHIBIT_ALL_WARNINGS = NO; GCC_TREAT_WARNINGS_AS_ERRORS = YES;
TEST_TARGET_NAME = "";'''
for scope, settings in [('project', project_settings), ('target', target_settings)]:
    for mode in ['debug','release']:
        objects.append(f'{i[scope+mode]} = {{isa = XCBuildConfiguration; buildSettings = {{{settings}}}; name = {mode.title()};}};')
    objects.append(f'{i[scope+"list"]} = {{isa = XCConfigurationList; buildConfigurations = ({i[scope+"debug"]}, {i[scope+"release"]}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;}};')
(project / 'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n' + '\n'.join(objects) + f'\n}}; rootObject = {i["project"]};}}\n', encoding='utf-8')
schemes = project / 'xcshareddata/xcschemes';schemes.mkdir(parents=True, exist_ok=True)
ref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{i["target"]}" BuildableName="AtlasLaunchUITests.xctest" BlueprintName="AtlasLaunchUITests" ReferencedContainer="container:LaunchWorkflow.xcodeproj"/>'
(schemes / 'AtlasLaunchUITests.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">{ref}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{ref}</TestableReference></Testables></TestAction>
</Scheme>''', encoding='utf-8')
print(project)
