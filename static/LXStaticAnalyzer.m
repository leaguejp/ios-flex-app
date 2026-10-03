#import "LXStaticAnalyzer.h"
#include "../core/macho.h"
#import "../shared/LXTypes.h"
static void LXStaticEmit(void *context,const char *key,const char *value) {
 if(!strcmp(key,"provenance")) return; // Record provenance is a scalar, never a metadata array.
 NSMutableDictionary *record=(__bridge NSMutableDictionary *)context;size_t length=strlen(value);NSUInteger used=[record[@"metadataBytes"] unsignedIntegerValue];
 if(length>=16384 || used+length>128*1024) { record[@"metadataTruncated"]=@YES;return; }
 record[@"metadataBytes"]=@(used+length);NSString *k=@(key),*v=@(value);
 if(!k || !v) { record[@"metadataError"]=@"invalid_utf8";return; }
 NSMutableArray *values=record[k];if(!values) { values=[NSMutableArray new];record[k]=values; }
 if(values.count<20000) [values addObject:v];
}
static void LXStaticClass(void *context,const char *name,int meta,const char *selector,const char *encoding) {
 NSMutableDictionary *record=(__bridge NSMutableDictionary *)context;
 NSString *className=@(name);if(!className) { record[@"metadataError"]=@"invalid_utf8";return; }
 NSMutableDictionary *classes=record[@"classMap"];NSMutableDictionary *cls=classes[className];
 if(!cls) { NSUInteger classBytes=[record[@"metadataBytes"] unsignedIntegerValue]+strlen(name)+[record[@"path"] length]+256;if(classBytes>128*1024) { record[@"metadataTruncated"]=@YES;return; }record[@"metadataBytes"]=@(classBytes);if(classes.count>=20000) { record[@"metadataTruncated"]=@YES;return; }cls=[@{@"name":className,@"image":record[@"path"],@"provenance":@"Static Only",@"methods":[NSMutableArray new]} mutableCopy];classes[className]=cls; }
 if(!selector) return;
 NSString *sel=@(selector),*type=@(encoding);if(!sel || !type) { record[@"metadataError"]=@"invalid_utf8";return; }
 NSUInteger bytes=[record[@"metadataBytes"] unsignedIntegerValue]+strlen(name)+strlen(selector)+strlen(encoding)+256;
 if(bytes>128*1024) { record[@"metadataTruncated"]=@YES;return; }record[@"metadataBytes"]=@(bytes);
 NSString *reason=LXStaticHookReason(record[@"bundle"],className,sel,meta!=0,type);
 [cls[@"methods"] addObject:@{@"class":className,@"classMethod":@(meta!=0),@"selector":sel,@"encoding":type,@"types":LXDescribeEncoding(type),@"image":record[@"path"],@"provenance":@"Static Only",@"supported":@(reason==nil),@"unsupportedReason":reason ?: @"",@"requiresRuntimeValidation":@YES}];
}
@implementation LXStaticAnalyzer
- (NSDictionary *)analyzeBundle:(NSString *)path {
 NSMutableArray *images=[NSMutableArray new],*errors=[NSMutableArray new];NSURL *root=[NSURL fileURLWithPath:path isDirectory:YES];
 NSNumber *directory=nil;NSError *rootError=nil;
 if(![root getResourceValue:&directory forKey:NSURLIsDirectoryKey error:&rootError] || !directory.boolValue) return @{@"images":@[],@"errors":@[@{@"code":@"io_error",@"path":path,@"detail":rootError.localizedDescription ?: @"Bundle directory unavailable"}],@"provenance":@"Static Only"};
 NSDirectoryEnumerator *enumerator=[NSFileManager.defaultManager enumeratorAtURL:root includingPropertiesForKeys:@[NSURLIsRegularFileKey,NSURLFileSizeKey,NSURLIsSymbolicLinkKey] options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:^BOOL(NSURL *url,NSError *e) {
  if(errors.count<256) [errors addObject:@{@"path":url.path,@"code":@"io_error",@"detail":e.localizedDescription}];return errors.count<256;
 }];
 NSString *bundle=[NSBundle bundleWithPath:path].bundleIdentifier ?: @"";
 NSUInteger visited=0,totalBytes=0;
 for(NSURL *url in enumerator) { @autoreleasepool {
  if(++visited>10000 || images.count>=256 || errors.count>=256) { [errors addObject:@{@"code":@"bundle_limit"}];break; }
  NSNumber *regular,*size,*link;[url getResourceValue:&regular forKey:NSURLIsRegularFileKey error:nil];[url getResourceValue:&size forKey:NSURLFileSizeKey error:nil];[url getResourceValue:&link forKey:NSURLIsSymbolicLinkKey error:nil];
  if(!regular.boolValue || link.boolValue || size.unsignedLongLongValue<4) continue;
  NSData *prefix=nil;NSFileHandle *file=nil;@try { file=[NSFileHandle fileHandleForReadingAtPath:url.path];if(file) prefix=[file readDataOfLength:4]; } @catch(NSException *exception) { [errors addObject:@{@"path":url.path,@"code":@"io_error",@"detail":exception.name}]; } @finally { @try { [file closeFile]; } @catch(NSException *exception) { (void)exception; } }if(prefix.length<4) continue;
  const uint8_t *p=prefix.bytes;BOOL macho=(p[0]==0xcf && p[1]==0xfa && p[2]==0xed && p[3]==0xfe)||(p[0]==0xfe && p[1]==0xed && p[2]==0xfa && p[3]==0xcf)||(p[0]==0xca && p[1]==0xfe && p[2]==0xba && (p[3]==0xbe || p[3]==0xbf));if(!macho) continue;
  if(size.unsignedLongLongValue>128ULL*1024*1024) { [errors addObject:@{@"path":url.path,@"code":@"file_limit"}];continue; }
  // Copy, not mmap: concurrent file truncation must not produce SIGBUS during parsing.
  NSError *io=nil;NSData *data=[NSData dataWithContentsOfURL:url options:NSDataReadingUncached error:&io];
  if(data.length>128ULL*1024*1024) { [errors addObject:@{@"path":url.path,@"code":@"file_limit"}];continue; }
  NSMutableDictionary *record=[@{@"path":url.path,@"name":url.lastPathComponent,@"provenance":@"Static Only",@"partial":@YES} mutableCopy];char error[128]={0};
  if(!data || !lx_macho(data.bytes,data.length,LXStaticEmit,(__bridge void *)record,error,sizeof(error)))
   [errors addObject:@{@"path":url.path,@"code":data?@(error):@"io_error",@"detail":io.localizedDescription ?: @"Static metadata may be partial"}];
  else {
   record[@"classMap"]=[NSMutableDictionary new];record[@"bundle"]=bundle;char objcError[128]={0};
   BOOL decoded=lx_macho_objc(data.bytes,data.length,LXStaticClass,(__bridge void *)record,objcError,sizeof(objcError));
   NSDictionary *map=record[@"classMap"];NSMutableArray *classes=[NSMutableArray new];for(NSString *name in [[map allKeys] sortedArrayUsingSelector:@selector(compare:)]) [classes addObject:map[name]];
   record[@"classes"]=classes;[record removeObjectForKey:@"classMap"];record[@"objcRelationshipsComplete"]=@(decoded && ![record[@"metadataTruncated"] boolValue]);
   if(!decoded) [errors addObject:@{@"path":url.path,@"code":@(objcError),@"detail":@"Objective-C relationships are partial; unresolved entries are not inferred"}];
   if(record[@"metadataError"]) [errors addObject:@{@"path":url.path,@"code":record[@"metadataError"],@"detail":@"A metadata string is not valid UTF-8; omitted from partial result"}];
   NSUInteger bytes=[NSJSONSerialization dataWithJSONObject:record options:0 error:nil].length;
   if(totalBytes+bytes>2*1024*1024) { [errors addObject:@{@"code":@"metadata_budget",@"detail":@"Static results capped at 2 MiB"}];break; }
   totalBytes+=bytes;[images addObject:record];
  }
 }}
 return @{@"images":images,@"errors":errors,@"provenance":@"Static Only",@"limitations":@[@"Partial arm64 class/metaclass method relationships; categories, bound external class references, arm64e authentication, multiple chain starts and Swift-only metadata are unsupported"]};
}
@end
