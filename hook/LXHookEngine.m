// Compiled without ARC: reviewed object-return wrapper preserves +0 convention.
#import "LXHookEngine.h"
#import "../shared/LXTypes.h"
#import "../shared/LXProtocol.h"
#include <pthread.h>
#include <time.h>
#include <sys/time.h>
#include <math.h>
#include <string.h>
static __thread unsigned LXDepth;
static uint64_t LXClock(void) { struct timespec ts={0};if(clock_gettime(CLOCK_MONOTONIC,&ts)) return 0;return (uint64_t)ts.tv_sec*1000000000ULL+ts.tv_nsec; }
static NSTimeInterval LXWall(void) { struct timeval tv={0};if(gettimeofday(&tv,NULL)) return 0;return (NSTimeInterval)tv.tv_sec+(NSTimeInterval)tv.tv_usec/1000000.0; }
static NSDictionary *LXObject(id obj) {
 const char *name=obj?class_getName(object_getClass(obj)):NULL;
 size_t length=name?strnlen(name,256):0;NSString *className=name?[[[NSString alloc] initWithBytes:name length:length encoding:NSUTF8StringEncoding] autorelease]:@"nil";
 return @{ @"pointer":[NSString stringWithFormat:@"%p",(void *)obj],@"runtimeClass":className ?: @"<invalid UTF-8>",@"classNameTruncated":@(length==256) };
}
static id LXScalar(NSNumber *value) {
 if(!isfinite(value.doubleValue)) return @{ @"nonFinite":isnan(value.doubleValue)?@"NaN":value.doubleValue>0?@"+Infinity":@"-Infinity" };
 return value;
}
@class LXRecord;
@interface LXHookEngine ()
- (NSDictionary *)copyPatchForRecord:(LXRecord *)record;
- (void)appendRecord:(LXRecord *)record args:(NSArray *)args result:(id)result start:(uint64_t)start wall:(NSTimeInterval)wall threw:(BOOL)threw;
@end
@interface LXRecord : NSObject
@property(nonatomic,assign) IMP original;
@property(nonatomic,assign) IMP replacement;
@property(nonatomic,assign) Method method;
@property(nonatomic,assign) SEL selector;
@property(nonatomic,assign) LXHookEngine *engine;
@property(nonatomic,copy) NSString *key;
@property(nonatomic,copy) NSString *encoding;
@property(nonatomic,copy) NSArray *types;
@property(nonatomic,copy) NSString *className;
@property(nonatomic,assign) BOOL enabled;
@property(nonatomic,copy) NSString *conflict;
@property(nonatomic,copy) NSDictionary *patch;
@end
@implementation LXRecord
- (void)dealloc { [_key release];[_encoding release];[_types release];[_className release];[_conflict release];[_patch release];[super dealloc]; }
@end
// Each cast below has an exact compiler-visible, reviewed C prototype. No generic ABI cast.
static IMP LXCreate(LXRecord *r,NSString *selector) {
 if([selector isEqual:@"ping"]) return imp_implementationWithBlock(^(id obj) {
  BOOL trace=(LXDepth++==0);uint64_t start=LXClock();NSTimeInterval wall=LXWall();BOOL threw=YES;
  @try { ((void(*)(id,SEL))r.original)(obj,r.selector);threw=NO; }
  @finally { --LXDepth;if(trace) { @autoreleasepool { @try { [r.engine appendRecord:r args:@[] result:NSNull.null start:start wall:wall threw:threw]; } @catch(NSException *e) { (void)e; } } } }
 });
 if([selector isEqual:@"classValue"]) return imp_implementationWithBlock(^long long(id obj) {
  BOOL trace=(LXDepth++==0);uint64_t start=LXClock();NSTimeInterval wall=LXWall();BOOL threw=YES;long long value=0;NSDictionary *patch=[r.engine copyPatchForRecord:r];
  @try { value=((long long(*)(id,SEL))r.original)(obj,r.selector);threw=NO;if(patch[@"return"]) value=[patch[@"return"] longLongValue];return value; }
  @finally { --LXDepth;if(trace) { @autoreleasepool { @try { [r.engine appendRecord:r args:@[] result:@(value) start:start wall:wall threw:threw]; } @catch(NSException *e) { (void)e; } } }[patch release]; }
 });
 if([selector isEqual:@"echo:"]) return imp_implementationWithBlock(^id(id obj,id arg) {
  BOOL trace=(LXDepth++==0);uint64_t start=LXClock();NSTimeInterval wall=LXWall();BOOL threw=YES;id value=nil;
  @try { value=((id(*)(id,SEL,id))r.original)(obj,r.selector,arg);threw=NO;return value; }
  @finally { --LXDepth;if(trace) { @autoreleasepool { @try { [r.engine appendRecord:r args:@[LXObject(arg)] result:LXObject(value) start:start wall:wall threw:threw]; } @catch(NSException *e) { (void)e; } } } }
 });
#define LX_SCALAR(SELECTOR,TYPE,ACCESSOR) \
 if([selector isEqual:@SELECTOR]) return imp_implementationWithBlock(^TYPE(id obj,TYPE arg) { \
 BOOL trace=(LXDepth++==0);uint64_t start=LXClock();NSTimeInterval wall=LXWall();BOOL threw=YES;TYPE value=0;NSDictionary *patch=[r.engine copyPatchForRecord:r];if(patch[@"argument"]) arg=(TYPE)[patch[@"argument"] ACCESSOR]; \
 @try { value=((TYPE(*)(id,SEL,TYPE))r.original)(obj,r.selector,arg);threw=NO;if(patch[@"return"]) value=(TYPE)[patch[@"return"] ACCESSOR];return value; } \
 @finally { --LXDepth;if(trace) { @autoreleasepool { @try { [r.engine appendRecord:r args:@[LXScalar(@(arg))] result:LXScalar(@(value)) start:start wall:wall threw:threw]; } @catch(NSException *e) { (void)e; } } }[patch release]; } \
 });
 LX_SCALAR("addOne:",long long,longLongValue)
 LX_SCALAR("invert:",BOOL,boolValue)
 LX_SCALAR("scale:",float,floatValue)
 LX_SCALAR("doubleValue:",double,doubleValue)
#undef LX_SCALAR
#define LX_VOID_SCALAR(SELECTOR,TYPE) \
 if([selector isEqual:@SELECTOR]) return imp_implementationWithBlock(^(id obj,TYPE arg) { \
 BOOL trace=(LXDepth++==0);uint64_t start=LXClock();NSTimeInterval wall=LXWall();BOOL threw=YES;NSDictionary *patch=[r.engine copyPatchForRecord:r];if(patch[@"argument"]) arg=(TYPE)[patch[@"argument"] doubleValue]; \
 @try { ((void(*)(id,SEL,TYPE))r.original)(obj,r.selector,arg);threw=NO; } \
 @finally { --LXDepth;if(trace) { @autoreleasepool { @try { [r.engine appendRecord:r args:@[LXScalar(@(arg))] result:NSNull.null start:start wall:wall threw:threw]; } @catch(NSException *e) { (void)e; } } }[patch release]; } \
 });
 LX_VOID_SCALAR("setHidden:",BOOL)
 LX_VOID_SCALAR("viewWillAppear:",BOOL)
 LX_VOID_SCALAR("viewDidAppear:",BOOL)
 LX_VOID_SCALAR("setAlpha:",double)
#undef LX_VOID_SCALAR
 return NULL;
}
@implementation LXHookEngine { NSRecursiveLock *_lock;NSMutableDictionary *_records;NSMutableArray *_retired;NSMutableArray *_events;NSUInteger _bytes; }
- (instancetype)init { if((self=[super init])) { _lock=[NSRecursiveLock new];_records=[NSMutableDictionary new];_retired=[NSMutableArray new];_events=[NSMutableArray new]; }return self; }
- (NSDictionary *)enableClass:(NSString *)name selector:(NSString *)selector classMethod:(BOOL)isClass {
 [_lock lock];@try {
  Class cls=objc_getClass(name.UTF8String);Class target=isClass?object_getClass(cls):cls;SEL sel=sel_registerName(selector.UTF8String);
  Method method=target?class_getInstanceMethod(target,sel):NULL;
  if(!method) return @{ @"error":LXError(@"method_missing",@"Class or method no longer exists") };
  NSString *encoding=@(method_getTypeEncoding(method));NSString *reason=LXHookReason(name,selector,isClass,encoding);
  if(reason) return @{ @"error":LXError(@"unsupported_signature",reason) };
  NSString *key=[NSString stringWithFormat:@"%@%@/%@",isClass?@"+":@"-",name,selector];
  LXRecord *existing=_records[key];if(existing.enabled) return @{ @"key":key,@"enabled":@YES };
  if(_retired.count>=256) return @{ @"error":LXError(@"generation_limit",@"Restart target after 256 hook generations") };
  // Never mutate a superclass Method when enumerating an inherited selector.
  BOOL owned=NO;unsigned count=0;Method *own=class_copyMethodList(target,&count);
  for(unsigned i=0;i<count;i++) if(own[i]==method) owned=YES;free(own);
  if(!owned) return @{ @"error":LXError(@"inherited_method",@"Only methods declared on this class can be hooked") };
  LXRecord *record=[[[LXRecord alloc] init] autorelease];record.original=method_getImplementation(method);record.method=method;
  record.selector=sel;record.engine=self;record.key=key;record.encoding=encoding;record.types=LXDescribeEncoding(encoding);record.className=name;
  record.replacement=LXCreate(record,selector);if(!record.replacement) return @{ @"error":LXError(@"unsupported_signature",@"No typed wrapper") };
  // Keep record and trampoline alive: an in-flight call or third-party chain may still reference it.
  [_retired addObject:record];_records[key]=record;
  IMP previous=method_setImplementation(method,record.replacement);
  if(previous!=record.original) {
   if(method_getImplementation(method)==record.replacement) method_setImplementation(method,previous);
   record.conflict=@"IMP changed during installation";return @{ @"error":LXError(@"hook_conflict",record.conflict) };
  }
  record.enabled=YES;return @{ @"key":key,@"enabled":@YES };
 } @finally { [_lock unlock]; }
}
- (NSDictionary *)copyPatchForRecord:(LXRecord *)record {
 [_lock lock];NSDictionary *copy=record.enabled?[record.patch copy]:nil;[_lock unlock];return copy;
}
- (NSDictionary *)configurePatch:(NSDictionary *)patch key:(NSString *)key {
 [_lock lock];@try {
  LXRecord *r=_records[key];if(!r.enabled) return @{ @"error":LXError(@"hook_inactive",@"Enable the reviewed hook before applying a patch") };
  if(![patch isKindOfClass:NSDictionary.class] || patch.count>2) return @{ @"error":LXError(@"invalid_patch",@"Expected argument / return scalar fields") };
  NSArray *types=LXDescribeEncoding(r.encoding);
  for(NSString *field in patch) {
   NSUInteger index=[field isEqual:@"return"]?0:[field isEqual:@"argument"]?3:NSUIntegerMax;
   if(index>=types.count) return @{ @"error":LXError(@"invalid_patch",@"Unknown field or absent argument") };
   NSString *encoding=types[index][@"encoding"];id value=patch[field];
   if(![value isKindOfClass:NSNumber.class] || !isfinite([value doubleValue])) return @{ @"error":LXError(@"invalid_patch",@"A finite JSON scalar number is required") };
   BOOL valid=NO;
   if([encoding isEqual:@"B"] || [encoding isEqual:@"c"]) valid=[value doubleValue]==0 || [value doubleValue]==1;
   else if([encoding isEqual:@"q"]) { NSDecimalNumber *number=[NSDecimalNumber decimalNumberWithDecimal:[value decimalValue]];valid=[number compare:[NSDecimalNumber decimalNumberWithString:@"-9223372036854775808"]]!=NSOrderedAscending && [number compare:[NSDecimalNumber decimalNumberWithString:@"9223372036854775807"]]!=NSOrderedDescending && [number compare:[NSDecimalNumber decimalNumberWithString:[value stringValue]]]==NSOrderedSame && floor([value doubleValue])==[value doubleValue]; }
   else if([encoding isEqual:@"f"]) valid=isfinite([value floatValue]);
   else if([encoding isEqual:@"d"]) valid=YES;
   if(!valid) return @{ @"error":LXError(@"unsupported_patch",@"Only BOOL, signed 64-bit integer, float and double fields within range can be patched") };
  }
  r.patch=patch;return @{ @"key":key,@"patch":patch,@"enabled":@YES };
 } @finally { [_lock unlock]; }
}
- (NSDictionary *)disableKey:(NSString *)key {
 [_lock lock];@try {
  LXRecord *r=_records[key];if(!r) return @{ @"error":LXError(@"hook_missing",@"Unknown hook") };
  if(!r.enabled) return @{ @"key":key,@"enabled":@NO };
  r.enabled=NO;
  if(method_getImplementation(r.method)!=r.replacement) { r.conflict=@"Third-party IMP detected; left untouched";return @{ @"error":LXError(@"hook_conflict",r.conflict) }; }
  IMP previous=method_setImplementation(r.method,r.original);
  if(previous!=r.replacement) { if(method_getImplementation(r.method)==r.original) method_setImplementation(r.method,previous);
   r.conflict=@"Concurrent external IMP change; restoration attempted";return @{ @"error":LXError(@"hook_conflict",r.conflict) }; }
  return @{ @"key":key,@"enabled":@NO };
 } @finally { [_lock unlock]; }
}
- (NSArray *)state {
 [_lock lock];NSMutableArray *out=[NSMutableArray array];
 for(LXRecord *r in _records.allValues) [out addObject:@{@"key":r.key,@"enabled":@(r.enabled),@"conflict":r.conflict ?: @"",@"encoding":r.encoding,@"patch":r.patch ?: @{}}];
 NSArray *copy=[[out copy] autorelease];[_lock unlock];return copy;
}
- (NSArray *)logs { [_lock lock];NSArray *copy=[[_events copy] autorelease];[_lock unlock];return copy; }
- (void)disableAll { [_lock lock];for(NSString *key in _records.allKeys) [self disableKey:key];[_lock unlock]; }
- (void)appendRecord:(LXRecord *)r args:(NSArray *)args result:(id)result start:(uint64_t)start wall:(NSTimeInterval)wall threw:(BOOL)threw {
 uint64_t elapsed=LXClock()-start;[_lock lock];@try {
 if(r.enabled) {
  uint64_t thread=0;pthread_threadid_np(NULL,&thread);
  NSDictionary *event=@{@"hook":r.key,@"class":r.className,@"selector":NSStringFromSelector(r.selector),@"encoding":r.encoding,@"types":r.types,@"time":@(wall),@"thread":@(thread),@"durationNs":@(elapsed),@"arguments":args,@"return":threw?NSNull.null:result ?: NSNull.null,@"exception":@(threw),@"patch":r.patch ?: @{}};
  NSData *data=[NSJSONSerialization dataWithJSONObject:event options:0 error:nil];
  if(data) { [_events addObject:event];_bytes+=data.length;
   while(_events.count>1000 || _bytes>1024*1024) { _bytes-=[NSJSONSerialization dataWithJSONObject:_events[0] options:0 error:nil].length;[_events removeObjectAtIndex:0]; } }
 }
 } @finally { [_lock unlock]; }
}
// Process-lifetime engine: trampolines can be retained by external chains. Do not deallocate it early.
@end
