#import <Foundation/Foundation.h>
#import "../controller/LXController.h"
#import "../shared/LXProtocol.h"
#include <assert.h>
@interface LXStore (TestFile)
- (NSURL *)file:(NSString *)bundle;
@end
static void checkRejected(LXController *controller,NSString *command,NSDictionary *payload) {
 LXSession *session=[LXSession new];session.identity=@{@"bundle":@"jp.league.runtimeatlas.storetest"};
 __block NSDictionary *received=nil;
 [controller request:command payload:@{@"offset":@0} session:session completion:^(NSDictionary *response) { received=response; }];
 void (^callback)(NSDictionary *)=session.pending.allValues.firstObject;assert(callback);
 callback(LXMessage(command,payload));assert([received[@"error"][@"code"] isEqual:@"bad_response"]);
}
int main(void) { @autoreleasepool {
 LXStore *store=[LXStore new];NSString *bundle=[@"jp.league.runtimeatlas.storetest." stringByAppendingString:NSUUID.UUID.UUIDString];NSURL *file=[store file:bundle];
 NSDictionary *malformed=@{@"history":@"not an array",@"logs":@[@{@"hook":NSNull.null}],@"desiredHooks":@{@"broken":@{@"request":NSNull.null,@"enabled":@YES}},@"patches":@{@"broken":NSNull.null}};
 assert([[NSJSONSerialization dataWithJSONObject:malformed options:0 error:nil] writeToURL:file atomically:YES]);
 NSDictionary *read=[store stateForBundle:bundle];assert(!read[@"history"] && !read[@"logs"] && ![read[@"desiredHooks"] count] && ![read[@"patches"] count]);
 assert([store save:malformed bundle:bundle]);assert(![store stateForBundle:bundle][@"history"]);
 NSDictionary *history=@{@"history":@[@"bad",@{@"command":@"images",@"response":@{},@"time":@1}]};assert([store save:history bundle:bundle]);assert([[store stateForBundle:bundle][@"history"] count]==1);
 assert([[NSMutableData dataWithLength:17*1024*1024] writeToURL:file atomically:YES]);assert(![store stateForBundle:bundle].count);
 NSDictionary *method=@{@"class":@"LXFixture",@"selector":@"addOne:",@"classMethod":@NO,@"encoding":@"q24@0:8q16",@"supported":@YES,@"provenance":@"Static Only"};NSString *fixture=@"jp.league.runtimeatlas.fixture";
 assert((![store savePatch:@{@"argument":@9,@"return":@77} method:method bundle:fixture]));
 NSDictionary *offline=[store stateForBundle:fixture];assert([offline[@"patches"][@"-LXFixture/addOne:"][@"return"] intValue]==77);assert(![offline[@"desiredHooks"][@"-LXFixture/addOne:"][@"enabled"] boolValue]);
 assert([store savePatch:@{@"return":@1.5} method:method bundle:fixture]);assert([store savePatch:@{@"return":@77} method:method bundle:bundle]);
 NSMutableDictionary *unsupported=[method mutableCopy];unsupported[@"supported"]=@NO;assert([store savePatch:@{@"return":@77} method:unsupported bundle:fixture]);
 NSURL *export=[store exportBundle:fixture error:nil];NSDictionary *json=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:export] options:0 error:nil];assert([json[@"desiredHooks"][@"-LXFixture/addOne:"][@"request"][@"provenance"] isEqual:@"Static Only"]);
 [NSFileManager.defaultManager removeItemAtURL:[store file:fixture] error:nil];[NSFileManager.defaultManager removeItemAtURL:export error:nil];
 [NSFileManager.defaultManager removeItemAtURL:file error:nil];
 LXController *controller=[LXController new];
 checkRejected(controller,@"methods",@{@"methods":NSNull.null,@"next":@1,@"total":@1});
 checkRejected(controller,@"classes",@{@"classes":@[],@"next":@0,@"total":@200});
 checkRejected(controller,@"images",@{@"images":@[@{@"name":@"image",@"path":@"image",@"provenance":@"Static Only"}]});
 checkRejected(controller,@"logs",@{@"logs":@[@{@"hook":@"hook",@"class":@"class",@"selector":@"selector",@"encoding":@"v@:",@"time":@1,@"thread":@1,@"durationNs":@1,@"arguments":NSNull.null}]});
 checkRejected(controller,@"catalogPage",@{@"captureID":@"not-requested",@"next":@1,@"total":@1,@"records":@[]});
 assert([store save:@{@"runtimeCatalog":NSNull.null} bundle:bundle]);assert(![store stateForBundle:bundle][@"runtimeCatalog"]);
 puts("Store/Controller: offline scalar patch save/reload/export, unsupported bundle/signature/range rejection; malformed saved JSON, bounded reads, malformed result collections/provenance and nonadvancing pagination rejected without exceptions");
 }return 0; }
