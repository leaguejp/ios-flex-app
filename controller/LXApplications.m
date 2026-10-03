#import "LXApplications.h"
#include <dlfcn.h>
#include <string.h>
// Private LaunchServices is optional. Check signatures before every invocation.
// No entitlement, jailbreak root path or assumed objc_msgSend prototype.
static id LXGet(id receiver,NSString *name) {
 SEL selector=NSSelectorFromString(name);NSMethodSignature *signature=[receiver methodSignatureForSelector:selector];
 if(!signature || signature.numberOfArguments!=2 || strcmp(signature.methodReturnType,@encode(id))) return nil;
 NSInvocation *call=[NSInvocation invocationWithMethodSignature:signature];call.target=receiver;call.selector=selector;[call invoke];
 __unsafe_unretained id value=nil;[call getReturnValue:&value];return value;
}
static id LXWorkspace(void) {
 // Platform framework path, independent of the jailbreak bootstrap location.
 static void *handle;static dispatch_once_t once;dispatch_once(&once,^{ handle=dlopen("/System/Library/Frameworks/CoreServices.framework/CoreServices",RTLD_LAZY); });(void)handle;
 return LXGet(NSClassFromString(@"LSApplicationWorkspace"),@"defaultWorkspace");
}
@implementation LXApplications
+ (NSArray<NSDictionary *> *)installed:(NSString **)failure {
 @try {
  id apps=LXGet(LXWorkspace(),@"allInstalledApplications");
  if(![apps isKindOfClass:NSArray.class]) { if(failure) *failure=@"Installed-app inventory is unavailable on this environment. Paired Agents remain accessible.";return @[]; }
  NSMutableArray *result=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];
  for(id proxy in apps) {
   id bundle=LXGet(proxy,@"applicationIdentifier");if(![bundle isKindOfClass:NSString.class] || [bundle hasPrefix:@"com.apple."] || [bundle isEqual:@"jp.league.runtimeatlas.controller"] || [seen containsObject:bundle]) continue;
   id title=LXGet(proxy,@"localizedName");id url=LXGet(proxy,@"bundleURL");[seen addObject:bundle];
   [result addObject:@{@"bundle":bundle,@"name":[title isKindOfClass:NSString.class]?title:bundle,@"bundlePath":[url isKindOfClass:NSURL.class]?[url path]:@""}];
  }
  return [result sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b) { return [a[@"name"] localizedCaseInsensitiveCompare:b[@"name"]]; }];
 } @catch(NSException *exception) { if(failure) *failure=[NSString stringWithFormat:@"Installed-app inventory failed: %@",exception.name];return @[]; }
}
+ (BOOL)openBundle:(NSString *)bundle {
 @try {
  id workspace=LXWorkspace();SEL selector=NSSelectorFromString(@"openApplicationWithBundleID:");NSMethodSignature *signature=[workspace methodSignatureForSelector:selector];
  if(!signature || signature.numberOfArguments!=3 || strcmp([signature getArgumentTypeAtIndex:2],@encode(id))) return NO;
  const char *type=signature.methodReturnType;if(strcmp(type,@encode(BOOL)) && strcmp(type,@encode(void))) return NO;
  NSInvocation *call=[NSInvocation invocationWithMethodSignature:signature];call.target=workspace;call.selector=selector;[call setArgument:&bundle atIndex:2];[call invoke];
  if(!strcmp(type,@encode(void))) return YES;BOOL value=NO;[call getReturnValue:&value];return value;
 } @catch(NSException *exception) { (void)exception;return NO; }
}
@end
