#import <UIKit/UIKit.h>
#import <Cephei/HBPreferences.h>
#import "shared/TemplateConfig.h"

static HBPreferences *ETPreferences;
static NSUInteger ETLoggedAppearances;

%group ETAppHooks
%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    // UIKit invokes this on the main thread. Never log arbitrary object descriptions.
    if ([ETPreferences boolForKey:ETEnabledKey] && ETLoggedAppearances < 20) {
        ETLoggedAppearances++;
        NSLog(@"[ExampleTweak] appeared class=%@", NSStringFromClass(self.class));
    }
}
%end
%end

%ctor {
    @autoreleasepool {
        // The loader filter and this guard must name the same application.
        if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:ETTargetBundle]) return;
        ETPreferences = [[HBPreferences alloc] initWithIdentifier:ETPreferencesDomain];
        [ETPreferences registerDefaults:@{ETEnabledKey: @NO}];
        %init(ETAppHooks);
        NSLog(@"[ExampleTweak] injected bundle=%@ enabled=%d", ETTargetBundle,
              [ETPreferences boolForKey:ETEnabledKey]);
    }
}
