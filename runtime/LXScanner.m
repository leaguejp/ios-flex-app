#import "LXScanner.h"
#import "../shared/LXTypes.h"
#import "../shared/LXProtocol.h"
#include <mach-o/dyld.h>
#include <objc/runtime.h>
#include <stdatomic.h>
static atomic_uint LXImageGeneration;
static void LXImagesChanged(const struct mach_header *header,intptr_t slide) { (void)header;(void)slide;atomic_fetch_add(&LXImageGeneration,1); }
@implementation LXScanner { unsigned _generation;NSArray *_images;NSMutableDictionary *_classCache; }
- (instancetype)init { if((self=[super init])) { _classCache=[NSMutableDictionary new];_generation=UINT_MAX;static dispatch_once_t once;dispatch_once(&once,^{ _dyld_register_func_for_add_image(LXImagesChanged);_dyld_register_func_for_remove_image(LXImagesChanged); }); }return self; }
- (NSDictionary *)images {
 unsigned gen=atomic_load(&LXImageGeneration);
 if(_generation!=gen) {
  NSMutableArray *out=[NSMutableArray new];uint32_t count=_dyld_image_count();
  for(uint32_t i=0;i<count;i++) { const char *name=_dyld_get_image_name(i);const struct mach_header *h=_dyld_get_image_header(i);if(!name || !h) continue;
   [out addObject:@{@"path":@(name),@"name":[@(name) lastPathComponent],@"header":[NSString stringWithFormat:@"%p",(const void *)h],@"cpuType":@(h->cputype),@"slide":@(_dyld_get_image_vmaddr_slide(i)),@"provenance":@"Runtime Loaded"}]; }
  _images=out;_generation=gen;[_classCache removeAllObjects];
 }
 return @{@"images":_images ?: @[],@"generation":@(_generation),@"provenance":@"Runtime Loaded"};
}
- (NSDictionary *)classesInImage:(NSString *)image offset:(NSUInteger)offset {
 [self images];NSArray *cached=_classCache[image];
 if([image isEqual:@"runtime://generated"]) {
  // A class without an image is registered runtime information, not a Mach-O file.
  unsigned count=0;Class *classes=objc_copyClassList(&count);NSMutableArray *rows=[NSMutableArray new];
  for(unsigned i=0;i<count;i++) { Class cls=classes[i];if(class_getImageName(cls)) continue;const char *raw=class_getName(cls);NSString *name=raw?@(raw):nil;if(!name) continue;Class parent=class_getSuperclass(cls);
   [rows addObject:@{@"name":name,@"superclass":parent?@(class_getName(parent)):@"",@"image":@"",@"source":@"Runtime Generated",@"provenance":@"Runtime Loaded"}];
  }free(classes);
  cached=[rows sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b) { return [a[@"name"] compare:b[@"name"]]; }];
 }

 if(!cached) {
  unsigned count=0;const char **names=objc_copyClassNamesForImage(image.UTF8String,&count);NSMutableArray *out=[NSMutableArray new];
  for(unsigned i=0;i<count;i++) { Class cls=objc_getClass(names[i]);Class parent=class_getSuperclass(cls);
   [out addObject:@{@"name":@(names[i]),@"superclass":parent?@(class_getName(parent)):@"",@"image":image,@"provenance":@"Runtime Loaded"}]; }
  free(names);
  if(!out.count) {
   NSString *resolved=[image stringByResolvingSymlinksInPath];unsigned total=0;Class *classes=objc_copyClassList(&total);
   for(unsigned i=0;i<total;i++) { const char *owner=class_getImageName(classes[i]);if(!owner || ![[@(owner) stringByResolvingSymlinksInPath] isEqual:resolved]) continue;Class parent=class_getSuperclass(classes[i]);
    [out addObject:@{@"name":@(class_getName(classes[i])),@"superclass":parent?@(class_getName(parent)):@"",@"image":image,@"provenance":@"Runtime Loaded"}];
   }free(classes);
  }
  cached=[out sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b) { return [a[@"name"] compare:b[@"name"]]; }];_classCache[image]=cached;
 }
 NSUInteger begin=MIN(offset,cached.count),n=MIN((NSUInteger)200,cached.count-begin);
 return @{@"classes":[cached subarrayWithRange:NSMakeRange(begin,n)],@"total":@(cached.count),@"next":@(begin+n),@"generation":@(_generation)};
}
- (NSDictionary *)methodsInClass:(NSString *)name {
 return [self methodsInClass:name offset:0];
}
- (NSDictionary *)methodsInClass:(NSString *)name offset:(NSUInteger)offset {
 Class cls=objc_getClass(name.UTF8String);if(!cls) return @{@"error":LXError(@"class_missing",@"Class not loaded")};
 NSMutableArray *out=[NSMutableArray new];
 for(unsigned kind=0;kind<2;kind++) { unsigned count=0;Method *methods=class_copyMethodList(kind?object_getClass(cls):cls,&count);
  for(unsigned i=0;i<count;i++) { NSString *sel=NSStringFromSelector(method_getName(methods[i]));const char *types=method_getTypeEncoding(methods[i]);NSString *encoding=types?@(types):@"";
   NSString *reason=LXHookReason(name,sel,kind!=0,encoding);
   [out addObject:@{@"class":name,@"selector":sel,@"classMethod":@(kind!=0),@"encoding":encoding,@"types":LXDescribeEncoding(encoding),@"supported":@(reason==nil),@"unsupportedReason":reason ?: @"",@"provenance":@"Runtime Loaded"}]; }
  free(methods);
 }
 NSArray *sorted=[out sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b) { NSComparisonResult kind=[a[@"classMethod"] compare:b[@"classMethod"]];return kind==NSOrderedSame?[a[@"selector"] compare:b[@"selector"]]:kind; }];
 NSUInteger begin=MIN(offset,sorted.count),length=MIN((NSUInteger)200,sorted.count-begin);
 return @{@"methods":[sorted subarrayWithRange:NSMakeRange(begin,length)],@"total":@(sorted.count),@"next":@(begin+length)};
}
@end
