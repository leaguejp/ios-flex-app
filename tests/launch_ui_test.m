#import <XCTest/XCTest.h>
@interface AtlasLaunchUITests : XCTestCase
@end
@implementation AtlasLaunchUITests
- (void)testAnalyzeSelectedAppAndReturn {
 self.continueAfterFailure=NO;
 XCUIApplication *atlas=[[XCUIApplication alloc] initWithBundleIdentifier:@"jp.league.runtimeatlas.controller"];
 atlas.launchArguments=@[@"--lx-test-record-launch-analysis"];[atlas launch];
 XCUIElement *row=[atlas.tables.cells containingPredicate:[NSPredicate predicateWithFormat:@"label CONTAINS %@ AND NOT label CONTAINS %@",@"jp.league.runtimeatlas.fixture",@"fixture.secondary"]].firstMatch;
 XCTAssertTrue([row waitForExistenceWithTimeout:10]);[row tap];
 XCUIElement *analyze=[atlas.tables.cells containingType:XCUIElementTypeStaticText matchingIdentifier:@"Analyze app / return to Atlas"].firstMatch;
 XCTAssertTrue(analyze.exists);[analyze tap];
 XCUIApplication *target=[[XCUIApplication alloc] initWithBundleIdentifier:@"jp.league.runtimeatlas.fixture"];
 XCUIApplication *system=[[XCUIApplication alloc] initWithBundleIdentifier:@"com.apple.springboard"];
 NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:35];BOOL returned=NO;
 while(deadline.timeIntervalSinceNow>0) {
  // Standard system permission interaction, not a TCC/defaults/entitlement bypass.
  for(XCUIApplication *app in @[system,target]) {
   XCUIElement *allow=app.alerts.buttons[@"Allow Paste"];if(allow.exists) [allow tap];
   XCUIElement *open=app.alerts.buttons[@"Open"];if(open.exists) [open tap];
  }
  if(atlas.state==XCUIApplicationStateRunningForeground && atlas.navigationBars[@"Captured Runtime Loaded"].exists) { returned=YES;break; }
  [NSThread sleepForTimeInterval:.2];
 }
 XCTAttachment *capture=[XCTAttachment attachmentWithScreenshot:XCUIScreen.mainScreen.screenshot];capture.lifetime=XCTAttachmentLifetimeKeepAlways;[self addAttachment:capture];
 XCTAssertTrue(returned,@"Target must capture and return to Atlas; an empty or timed-out job is not success");
 XCUIElement *image=[atlas.tables.cells containingType:XCUIElementTypeStaticText matchingIdentifier:@"AtlasTestTarget"].firstMatch;XCTAssertTrue(image.exists);[image tap];
 XCUIElement *fixture=[atlas.tables.cells containingType:XCUIElementTypeStaticText matchingIdentifier:@"LXFixture"].firstMatch;XCTAssertTrue(fixture.exists);[fixture tap];
 XCTAssertTrue(atlas.staticTexts[@"- addOne:"].exists);XCTAssertTrue(atlas.staticTexts[@"+ classValue"].exists);
 XCTAttachment *methods=[XCTAttachment attachmentWithScreenshot:XCUIScreen.mainScreen.screenshot];methods.lifetime=XCTAttachmentLifetimeKeepAlways;[self addAttachment:methods];
}
@end
