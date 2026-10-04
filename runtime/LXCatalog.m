#import "LXCatalog.h"
#import "LXScanner.h"
#import "../shared/LXProtocol.h"
@implementation LXCatalog { NSMutableArray *_records;NSUInteger _bytes;NSString *_identifier; }
- (BOOL)add:(NSDictionary *)record {
 NSUInteger bytes=[NSJSONSerialization dataWithJSONObject:record options:0 error:nil].length;
 if(!bytes || _bytes+bytes>8*1024*1024 || _records.count>=50000) return NO;
 [_records addObject:record];_bytes+=bytes;return YES;
}
- (NSDictionary *)capture:(LXScanner *)scanner bundlePath:(NSString *)path {
 _records=[NSMutableArray new];_bytes=0;_identifier=NSUUID.UUID.UUIDString;NSMutableArray *errors=[NSMutableArray new];NSUInteger images=0,classes=0,methods=0;
 NSTimeInterval start=NSDate.date.timeIntervalSince1970;NSString *root=[[path stringByResolvingSymlinksInPath] stringByAppendingString:@"/"];
 NSMutableArray *selected=[NSMutableArray new];
 for(NSDictionary *image in [scanner images][@"images"]) if([[image[@"path"] stringByResolvingSymlinksInPath] hasPrefix:root]) [selected addObject:image];
 // Dynamic registrations have no file identity; keep an explicit virtual group.
 [selected addObject:@{@"name":@"Runtime Generated",@"path":@"runtime://generated",@"kind":@"virtualClassGroup",@"provenance":@"Runtime Loaded"}];
 for(NSDictionary *image in selected) { @autoreleasepool {
  if(![self add:@{@"kind":@"image",@"data":image}]) goto limited;images++;
  NSUInteger offset=0;
  do {
   NSDictionary *page=[scanner classesInImage:image[@"path"] offset:offset];
   for(NSDictionary *cls in page[@"classes"]) { @autoreleasepool {
    if(NSDate.date.timeIntervalSince1970-start>10) goto limited;
    NSMutableDictionary *classInfo=[cls mutableCopy];classInfo[@"image"]=image[@"path"];
    if(![self add:@{@"kind":@"class",@"data":classInfo}]) goto limited;classes++;
    NSUInteger methodOffset=0;
    do {
     NSDictionary *methodPage=[scanner methodsInClass:cls[@"name"] offset:methodOffset];
     if(methodPage[@"error"]) { [errors addObject:methodPage[@"error"]];break; }
     for(NSDictionary *method in methodPage[@"methods"]) {
      NSMutableDictionary *info=[method mutableCopy];info[@"image"]=image[@"path"];
      if(![self add:@{@"kind":@"method",@"data":info}]) goto limited;methods++;
     }
     methodOffset=[methodPage[@"next"] unsignedIntegerValue];if(methodOffset>=[methodPage[@"total"] unsignedIntegerValue]) break;
    }while(YES);
   }}
   offset=[page[@"next"] unsignedIntegerValue];if(offset>=[page[@"total"] unsignedIntegerValue]) break;
  }while(YES);
 }}
 goto done;
limited: [errors addObject:LXError(@"capture_limit",@"Partial capture: 10 second / 8 MiB / 50,000 record budget reached")];
done:
 if(!methods) [errors addObject:LXError(@"no_objc_methods",@"No Objective-C methods captured in the app bundle. Swift-only/native code may not expose Objective-C methods; check image and class diagnostics.")];
 return @{@"captureID":_identifier,@"total":@(_records.count),@"imageCount":@(images),@"classCount":@(classes),@"methodCount":@(methods),@"capturedAt":@(start),@"partial":@(errors.count>0),@"errors":errors,@"scope":@"App Bundle + Runtime Generated",@"provenance":@"Runtime Loaded"};
}
- (NSDictionary *)page:(NSString *)captureID offset:(NSUInteger)offset {
 if(![_identifier isEqual:captureID] || offset>_records.count) return @{@"error":LXError(@"capture_missing",@"Capture expired or cursor invalid; analyze again")};
 NSUInteger count=MIN((NSUInteger)100,_records.count-offset);
 return @{@"captureID":_identifier,@"records":[_records subarrayWithRange:NSMakeRange(offset,count)],@"next":@(offset+count),@"total":@(_records.count)};
}
- (NSDictionary *)snapshot:(NSDictionary *)metadata bundle:(NSString *)bundle request:(NSString *)request pid:(NSNumber *)pid {
 NSMutableArray *images=[NSMutableArray new];NSMutableDictionary *imageByPath=[NSMutableDictionary new],*classByName=[NSMutableDictionary new];
 for(NSDictionary *record in _records) {
  NSDictionary *data=record[@"data"];NSString *kind=record[@"kind"];
  if([kind isEqual:@"image"]) { NSMutableDictionary *image=[data mutableCopy];image[@"classes"]=[NSMutableArray new];[images addObject:image];imageByPath[data[@"path"]]=image; }
  else if([kind isEqual:@"class"]) { NSMutableDictionary *owner=imageByPath[data[@"image"]];if(!owner || classByName[data[@"name"]]) return nil;NSMutableDictionary *cls=[data mutableCopy];cls[@"methods"]=[NSMutableArray new];[owner[@"classes"] addObject:cls];classByName[data[@"name"]]=cls; }
  else { NSMutableDictionary *cls=classByName[data[@"class"]];if(!cls || ![cls[@"image"] isEqual:data[@"image"]]) return nil;[cls[@"methods"] addObject:data]; }
 }
 NSDictionary *catalog=@{@"metadata":metadata,@"images":images,@"bundle":bundle,@"requestID":request,@"pid":pid};return LXRuntimeCatalogReason(catalog)?nil:catalog;
}
@end
