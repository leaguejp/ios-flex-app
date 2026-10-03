#import "LXProtocol.h"
#include <unistd.h>
#include <math.h>
NSDictionary *LXError(NSString *code,NSString *detail) { return @{ @"code":code,@"detail":detail ?: @"" }; }
NSDictionary *LXMessage(NSString *command,NSDictionary *payload) {
 return @{ @"namespace":LXIPCNamespace,@"version":@LXProtocolVersion,@"pid":@(getpid()),@"bundle":NSBundle.mainBundle.bundleIdentifier ?: @"unknown",
 @"command":command,@"commandID":NSUUID.UUID.UUIDString,@"responseID":@"",@"error":NSNull.null,@"payload":payload ?: @{} };
}
BOOL LXValidate(NSDictionary *m) {
 if(![m isKindOfClass:NSDictionary.class]) return NO;
 if(![m[@"namespace"] isEqual:LXIPCNamespace]) return NO;
 if(![m[@"version"] isKindOfClass:NSNumber.class] || [m[@"version"] doubleValue]!=LXProtocolVersion) return NO;
 if(![m[@"pid"] isKindOfClass:NSNumber.class] || !isfinite([m[@"pid"] doubleValue]) || floor([m[@"pid"] doubleValue])!=[m[@"pid"] doubleValue] || [m[@"pid"] doubleValue]<=0 || [m[@"pid"] doubleValue]>INT_MAX) return NO;
 for(NSString *k in @[@"bundle",@"command",@"commandID",@"responseID"])
  if(![m[k] isKindOfClass:NSString.class] || [m[k] length]>512) return NO;
 if(![m[@"commandID"] length] || ![m[@"bundle"] length]) return NO;
 id error=m[@"error"];
 if(error!=NSNull.null && (![error isKindOfClass:NSDictionary.class] || ![error[@"code"] isKindOfClass:NSString.class] || ![error[@"detail"] isKindOfClass:NSString.class])) return NO;
 return [m[@"payload"] isKindOfClass:NSDictionary.class];
}
static BOOL LXFields(NSDictionary *record,NSArray *strings,NSArray *numbers) {
 if(![record isKindOfClass:NSDictionary.class]) return NO;
 for(NSString *key in strings) if(![record[key] isKindOfClass:NSString.class]) return NO;
 for(NSString *key in numbers) if(![record[key] isKindOfClass:NSNumber.class] || !isfinite([record[key] doubleValue])) return NO;
 return YES;
}
NSString *LXResultReason(NSString *command,NSDictionary *payload,NSDictionary *request) {
 if(![payload isKindOfClass:NSDictionary.class]) return @"Response payload must be a dictionary";
 NSString *collection=nil;NSArray *strings=@[],*numbers=@[];NSUInteger cap=65536;
 if([command isEqual:@"images"] || [command isEqual:@"static"]) {
  collection=@"images";strings=@[@"name",@"path",@"provenance"];
  if([command isEqual:@"static"]) { cap=256;if(![payload[@"errors"] isKindOfClass:NSArray.class]) return @"Static errors must be an array";for(id error in payload[@"errors"]) if(![error isKindOfClass:NSDictionary.class]) return @"Malformed static error"; }
 } else if([command isEqual:@"classes"]) { collection=@"classes";strings=@[@"name",@"superclass",@"image",@"provenance"];cap=200;
 } else if([command isEqual:@"methods"]) { collection=@"methods";strings=@[@"class",@"selector",@"encoding",@"unsupportedReason",@"provenance"];numbers=@[@"supported",@"classMethod"];cap=200;
 } else if([command isEqual:@"logs"]) { collection=@"logs";strings=@[@"hook",@"class",@"selector",@"encoding"];numbers=@[@"time",@"thread",@"durationNs"];cap=1000;
 } else if([command isEqual:@"state"]) { collection=@"hooks";strings=@[@"key",@"encoding",@"conflict"];numbers=@[@"enabled"];cap=256;
 } else if([command isEqual:@"hookEnable"] || [command isEqual:@"hookDisable"] || [command isEqual:@"patchApply"]) {
  if(!LXFields(payload,@[@"key"],@[@"enabled"])) return @"Malformed hook result";
  if([command isEqual:@"patchApply"] && ![payload[@"patch"] isKindOfClass:NSDictionary.class]) return @"Malformed patch result";
 } else if([command isEqual:@"activate"] || [command isEqual:@"deactivate"]) {
  if(!LXFields(payload,@[@"bundle",@"executable",@"bundlePath"],@[@"pid",@"active"])) return @"Malformed Agent identity";
 } else if([command isEqual:@"patchPolicy"]) { if(!LXFields(payload,@[],@[@"applyOnLaunch"])) return @"Malformed launch policy";
 } else if([command isEqual:@"ping"]) { if(![payload[@"echo"] isKindOfClass:NSDictionary.class]) return @"Malformed ping echo"; }
 if(collection) {
  id items=payload[collection];if(![items isKindOfClass:NSArray.class] || [items count]>cap) return @"Malformed or oversized result collection";
  for(NSDictionary *record in items) {
   if(!LXFields(record,strings,numbers)) return @"Malformed result record";
   if([command isEqual:@"methods"] && ![record[@"types"] isKindOfClass:NSArray.class]) return @"Malformed method types";
   if([command isEqual:@"logs"] && ![record[@"arguments"] isKindOfClass:NSArray.class]) return @"Malformed logged arguments";
   if([@[@"images",@"classes",@"methods",@"static"] containsObject:command] && ![record[@"provenance"] isEqual:[command isEqual:@"static"]?@"Static Only":@"Runtime Loaded"]) return @"Unexpected source provenance";
  }
 }
 if([command isEqual:@"classes"] || [command isEqual:@"methods"]) {
  if(!LXFields(payload,@[],@[@"next",@"total"])) return @"Missing pagination counts";
  double next=[payload[@"next"] doubleValue],total=[payload[@"total"] doubleValue],offset=[request[@"offset"] doubleValue];
  if(next<0 || total<0 || floor(next)!=next || floor(total)!=total || next>total || (next<total && next<=offset)) return @"Pagination does not advance";
 }
 return nil;
}
