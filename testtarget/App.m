#import <UIKit/UIKit.h>
#import "LXFixture.h"
#if LX_FIXTURE_AUTOMATION
#import "../agent/LXAgent.h"
#endif
@interface LXTestApp : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation LXTestApp { UITextView *_text;LXFixture *_fixture;UIViewController *_view; }
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
 (void)app;(void)options;_fixture=[LXFixture new];_view=[UIViewController new];_view.title=@"Atlas TestTarget";_view.view.backgroundColor=UIColor.systemBackgroundColor;
 UIStackView *stack=[UIStackView new];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=12;stack.translatesAutoresizingMaskIntoConstraints=NO;[_view.view addSubview:stack];
 for(NSString *name in @[@"Pair Agent / IPC probe",@"Call reviewed methods",@"Call in 5 seconds"]) {
  UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];[button setTitle:name forState:UIControlStateNormal];[button addTarget:self action:[name hasPrefix:@"Pair"]?@selector(pair):[name hasPrefix:@"Call in"]?@selector(delayed):@selector(run) forControlEvents:UIControlEventTouchUpInside];[stack addArrangedSubview:button];
 }
 _text=[UITextView new];_text.editable=NO;_text.font=[UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];_text.text=@"Pair with Controller, activate, browse LXFixture and enable a supported hook. Return here and call methods. Inspect logs in Controller. Struct and variadic are browse-only.";[stack addArrangedSubview:_text];
 [NSLayoutConstraint activateConstraints:@[[stack.topAnchor constraintEqualToAnchor:_view.view.safeAreaLayoutGuide.topAnchor constant:20],[stack.bottomAnchor constraintEqualToAnchor:_view.view.safeAreaLayoutGuide.bottomAnchor constant:-20],[stack.leadingAnchor constraintEqualToAnchor:_view.view.leadingAnchor constant:16],[stack.trailingAnchor constraintEqualToAnchor:_view.view.trailingAnchor constant:-16]]];
 self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];self.window.rootViewController=[[UINavigationController alloc] initWithRootViewController:_view];[self.window makeKeyAndVisible];
#if LX_FIXTURE_AUTOMATION
 NSArray *args=NSProcessInfo.processInfo.arguments;NSUInteger position=[args indexOfObject:@"--lx-test-token"];
 if(position!=NSNotFound && position+1<args.count) [[LXAgent shared] connectFixtureTestToken:args[position+1]];
#endif
 return YES;
}
- (void)pair {
 Class cls=NSClassFromString(@"LXAgent");SEL shared=NSSelectorFromString(@"shared"),pair=NSSelectorFromString(@"pairFromController:");
 if(!cls) { _text.text=@"Agent not loaded. Enable TestTarget tweak injection in jailbreak settings, then relaunch.";return; }
 // NSInvocation avoids unspecified performSelector ownership warnings.
 NSInvocation *get=[NSInvocation invocationWithMethodSignature:[cls methodSignatureForSelector:shared]];get.target=cls;get.selector=shared;[get invoke];__unsafe_unretained id agent=nil;[get getReturnValue:&agent];
 NSInvocation *invoke=[NSInvocation invocationWithMethodSignature:[agent methodSignatureForSelector:pair]];invoke.target=agent;invoke.selector=pair;id vc=_view;[invoke setArgument:&vc atIndex:2];[invoke invoke];
}
- (void)delayed { _text.text=@"Calls scheduled. Switch back to Controller within 5 seconds.";dispatch_after(dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC),dispatch_get_main_queue(),^{ [self run]; }); }
- (void)run {
 [_fixture ping];id object=[_fixture echo:@"permitted fixture"];long long integer=[_fixture addOne:41];BOOL boolean=[_fixture invert:NO];float f=[_fixture scale:2];double d=[_fixture doubleValue:2.5];long long c=[LXFixture classValue];LXPoint p=[_fixture point:(LXPoint){1,2}];
 BOOL pass=integer==42 && boolean && f==3 && d==5 && c==42 && p.x==2 && [object isEqual:@"permitted fixture"];
 _text.text=[NSString stringWithFormat:@"%@\npings=%lu\nobject=%@\ninteger=%lld BOOL=%d float=%.1f double=%.1f class=%lld struct=(%.1f,%.1f)\n\nOriginal behavior must be identical with hooks enabled or disabled.",pass?@"PASS":@"FAIL",(unsigned long)_fixture.pings,object,integer,boolean,f,d,c,p.x,p.y];
}
@end
int main(int argc,char **argv) { @autoreleasepool { return UIApplicationMain(argc,argv,nil,NSStringFromClass(LXTestApp.class)); } }
