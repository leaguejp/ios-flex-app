#import "LXAgent.h"
#import <UIKit/UIKit.h>
__attribute__((constructor)) static void LXLoad(void) {
 @autoreleasepool {
  NSString *bundle=NSBundle.mainBundle.bundleIdentifier ?: @"";
  if(![NSBundle.mainBundle.bundlePath.pathExtension isEqual:@"app"] || [bundle hasPrefix:@"com.apple."] || [bundle isEqual:@"jp.league.runtimeatlas.controller"]) return;
  (void)[LXAgent shared]; // Only previously authorized launch patches may activate during startup.

 }
}
