#import "LXAgent.h"
#import <UIKit/UIKit.h>
__attribute__((constructor)) static void LXLoad(void) {
 @autoreleasepool {
  NSString *bundle=NSBundle.mainBundle.bundleIdentifier ?: @"";
  if(![NSBundle.mainBundle.bundlePath.pathExtension isEqual:@"app"] || [bundle hasPrefix:@"com.apple."] || [bundle isEqual:@"jp.league.runtimeatlas.controller"]) return;
  [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) { (void)note;[[LXAgent shared] installPairingGesture]; }];
 }
}
