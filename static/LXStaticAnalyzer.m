#import "LXStaticAnalyzer.h"
#include "../core/macho.h"
static void LXStaticEmit(void *context,const char *key,const char *value) {
 NSMutableDictionary *record=(__bridge NSMutableDictionary *)context;size_t length=strlen(value);NSUInteger used=[record[@"metadataBytes"] unsignedIntegerValue];
 if(length>=16384 || used+length>128*1024) { record[@"metadataTruncated"]=@YES;return; }
 record[@"metadataBytes"]=@(used+length);NSString *k=@(key),*v=@(value);
 NSMutableArray *values=record[k];if(!values) { values=[NSMutableArray new];record[k]=values; }
 if(values.count<20000) [values addObject:v];
}
@implementation LXStaticAnalyzer
- (NSDictionary *)analyzeBundle:(NSString *)path {
 NSMutableArray *images=[NSMutableArray new],*errors=[NSMutableArray new];NSURL *root=[NSURL fileURLWithPath:path isDirectory:YES];
 NSDirectoryEnumerator *enumerator=[NSFileManager.defaultManager enumeratorAtURL:root includingPropertiesForKeys:@[NSURLIsRegularFileKey,NSURLFileSizeKey,NSURLIsSymbolicLinkKey] options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:^BOOL(NSURL *url,NSError *e) {
  [errors addObject:@{@"path":url.path,@"code":@"io_error",@"detail":e.localizedDescription}];return YES;
 }];
 NSUInteger visited=0,totalBytes=0;
 for(NSURL *url in enumerator) { @autoreleasepool {
  if(++visited>10000 || images.count>=256) { [errors addObject:@{@"code":@"bundle_limit"}];break; }
  NSNumber *regular,*size,*link;[url getResourceValue:&regular forKey:NSURLIsRegularFileKey error:nil];[url getResourceValue:&size forKey:NSURLFileSizeKey error:nil];[url getResourceValue:&link forKey:NSURLIsSymbolicLinkKey error:nil];
  if(!regular.boolValue || link.boolValue || size.unsignedLongLongValue<4) continue;
  NSFileHandle *file=[NSFileHandle fileHandleForReadingAtPath:url.path];NSData *prefix=[file readDataOfLength:4];[file closeFile];if(prefix.length<4) continue;
  const uint8_t *p=prefix.bytes;BOOL macho=(p[0]==0xcf && p[1]==0xfa && p[2]==0xed && p[3]==0xfe)||(p[0]==0xfe && p[1]==0xed && p[2]==0xfa && p[3]==0xcf)||(p[0]==0xca && p[1]==0xfe && p[2]==0xba && (p[3]==0xbe || p[3]==0xbf));if(!macho) continue;
  if(size.unsignedLongLongValue>256ULL*1024*1024) { [errors addObject:@{@"path":url.path,@"code":@"file_limit"}];continue; }
  NSError *io=nil;NSData *data=[NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:&io];
  NSMutableDictionary *record=[@{@"path":url.path,@"name":url.lastPathComponent,@"provenance":@"Static Only",@"partial":@YES} mutableCopy];char error[128]={0};
  if(!data || !lx_macho(data.bytes,data.length,LXStaticEmit,(__bridge void *)record,error,sizeof(error)))
   [errors addObject:@{@"path":url.path,@"code":data?@(error):@"io_error",@"detail":io.localizedDescription ?: @"Static metadata may be partial"}];
  else {
   NSUInteger bytes=[NSJSONSerialization dataWithJSONObject:record options:0 error:nil].length;
   if(totalBytes+bytes>2*1024*1024) { [errors addObject:@{@"code":@"metadata_budget",@"detail":@"Static results capped at 2 MiB"}];break; }
   totalBytes+=bytes;[images addObject:record];
  }
 }}
 return @{@"images":images,@"errors":errors,@"provenance":@"Static Only",@"limitations":@[@"Objective-C string pools only; class/method relationships and chained fixups are not resolved"]};
}
@end
