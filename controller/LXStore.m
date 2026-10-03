#import "LXStore.h"
#import <CommonCrypto/CommonDigest.h>
@implementation LXStore
- (NSURL *)root {
 NSURL *base=[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
 NSURL *root=[base URLByAppendingPathComponent:@"jp.league.runtimeatlas.controller" isDirectory:YES];
 [NSFileManager.defaultManager createDirectoryAtURL:root withIntermediateDirectories:YES attributes:@{NSFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication} error:nil];return root;
}
- (NSURL *)file:(NSString *)bundle {
 NSData *bytes=[bundle dataUsingEncoding:NSUTF8StringEncoding];unsigned char digest[CC_SHA256_DIGEST_LENGTH];CC_SHA256(bytes.bytes,(CC_LONG)bytes.length,digest);char hex[65];for(unsigned i=0;i<32;i++) snprintf(hex+i*2,3,"%02x",digest[i]);NSString *name=@(hex);
 return [[self root] URLByAppendingPathComponent:[name stringByAppendingString:@".json"]];
}
- (NSDictionary *)stateForBundle:(NSString *)bundle {
 NSData *data=[NSData dataWithContentsOfURL:[self file:bundle]];if(!data || data.length>16*1024*1024) return @{};
 id state=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];return [state isKindOfClass:NSDictionary.class]?state:@{};
}
- (BOOL)save:(NSDictionary *)state bundle:(NSString *)bundle {
 NSMutableDictionary *bounded=[state mutableCopy];NSMutableArray *history=[bounded[@"history"] mutableCopy] ?: [NSMutableArray new];
 NSData *data=[NSJSONSerialization dataWithJSONObject:bounded options:NSJSONWritingSortedKeys error:nil];
 while(data.length>16*1024*1024 && history.count) { [history removeObjectAtIndex:0];bounded[@"history"]=history;bounded[@"historyTruncated"]=@YES;data=[NSJSONSerialization dataWithJSONObject:bounded options:NSJSONWritingSortedKeys error:nil]; }
 return data && data.length<=16*1024*1024 && [data writeToURL:[self file:bundle] options:NSDataWritingAtomic error:nil];
}
- (NSURL *)exportBundle:(NSString *)bundle error:(NSError **)error {
 NSMutableDictionary *out=[[self stateForBundle:bundle] mutableCopy];out[@"bundle"]=bundle;out[@"schemaVersion"]=@1;out[@"exportedAt"]=@(NSDate.date.timeIntervalSince1970);
 NSData *data=[NSJSONSerialization dataWithJSONObject:out options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:error];
 NSURL *url=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"RuntimeAtlas-%@.json",NSUUID.UUID.UUIDString]]];
 return [data writeToURL:url options:NSDataWritingAtomic error:error]?url:nil;
}
@end
