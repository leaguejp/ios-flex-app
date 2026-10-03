#import "LXProtocol.h"
#include <unistd.h>
NSDictionary *LXError(NSString *code,NSString *detail) { return @{ @"code":code,@"detail":detail ?: @"" }; }
NSDictionary *LXMessage(NSString *command,NSDictionary *payload) {
 return @{ @"namespace":LXIPCNamespace,@"version":@LXProtocolVersion,@"pid":@(getpid()),@"bundle":NSBundle.mainBundle.bundleIdentifier ?: @"unknown",
 @"command":command,@"commandID":NSUUID.UUID.UUIDString,@"responseID":@"",@"error":NSNull.null,@"payload":payload ?: @{} };
}
BOOL LXValidate(NSDictionary *m) {
 if(![m isKindOfClass:NSDictionary.class]) return NO;
 if(![m[@"namespace"] isEqual:LXIPCNamespace]) return NO;
 if(![m[@"version"] isKindOfClass:NSNumber.class] || [m[@"version"] integerValue]!=LXProtocolVersion) return NO;
 if(![m[@"pid"] isKindOfClass:NSNumber.class] || [m[@"pid"] longLongValue]<=0 || [m[@"pid"] longLongValue]>INT_MAX) return NO;
 for(NSString *k in @[@"bundle",@"command",@"commandID",@"responseID"])
  if(![m[k] isKindOfClass:NSString.class] || [m[k] length]>512) return NO;
 if(![m[@"commandID"] length] || ![m[@"bundle"] length]) return NO;
 id error=m[@"error"];
 if(error!=NSNull.null && (![error isKindOfClass:NSDictionary.class] || ![error[@"code"] isKindOfClass:NSString.class] || ![error[@"detail"] isKindOfClass:NSString.class])) return NO;
 return [m[@"payload"] isKindOfClass:NSDictionary.class];
}
