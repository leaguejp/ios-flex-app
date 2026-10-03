#import "LXStore.h"
@implementation LXStore
- (NSURL *)root {
 NSURL *base=[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
 NSURL *root=[base URLByAppendingPathComponent:@"jp.league.runtimeatlas.controller" isDirectory:YES];
 [NSFileManager.defaultManager createDirectoryAtURL:root withIntermediateDirectories:YES attributes:@{NSFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication} error:nil];return root;
}
- (NSURL *)file:(NSString *)bundle {
 NSData *bytes=[bundle dataUsingEncoding:NSUTF8StringEncoding];NSString *name=[bytes base64EncodedStringWithOptions:0];name=[[name stringByReplacingOccurrencesOfString:@"/" withString:@"_"] stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
 return [[self root] URLByAppendingPathComponent:[name stringByAppendingString:@".json"]];
}
- (NSDictionary *)stateForBundle:(NSString *)bundle {
 NSData *data=[NSData dataWithContentsOfURL:[self file:bundle]];if(!data || data.length>16*1024*1024) return @{};
 id state=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];return [state isKindOfClass:NSDictionary.class]?state:@{};
}
- (void)save:(NSDictionary *)state bundle:(NSString *)bundle {
 NSData *data=[NSJSONSerialization dataWithJSONObject:state options:NSJSONWritingSortedKeys error:nil];if(data.length<=16*1024*1024) [data writeToURL:[self file:bundle] options:NSDataWritingAtomic error:nil];
}
- (NSURL *)exportBundle:(NSString *)bundle error:(NSError **)error {
 NSMutableDictionary *out=[[self stateForBundle:bundle] mutableCopy];out[@"bundle"]=bundle;out[@"schemaVersion"]=@1;out[@"exportedAt"]=@(NSDate.date.timeIntervalSince1970);
 NSData *data=[NSJSONSerialization dataWithJSONObject:out options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:error];
 NSURL *url=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"RuntimeAtlas-%@.json",NSUUID.UUID.UUIDString]]];
 return [data writeToURL:url options:NSDataWritingAtomic error:error]?url:nil;
}
@end
