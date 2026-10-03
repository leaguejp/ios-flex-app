#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "../testtarget/LXFixture.h"
#import "../hook/LXHookEngine.h"
#import "../runtime/LXScanner.h"
#import "../shared/LXTypes.h"
#include <assert.h>
static long long LXForeign(id self,SEL cmd,long long value) { (void)self;(void)cmd;return value+99; }
int main(void) { @autoreleasepool {
 LXFixture *f=[LXFixture new];LXHookEngine *engine=[LXHookEngine new];LXScanner *scanner=[LXScanner new];
 NSDictionary *images=[scanner images];assert([images[@"images"] count]>0);
 NSDictionary *methods=[scanner methodsInClass:@"LXFixture"];assert([methods[@"methods"] count]>=9);
 const char *image=class_getImageName(LXFixture.class);assert(image);
 NSDictionary *classes=[scanner classesInImage:@(image) offset:0];assert([classes[@"total"] unsignedIntegerValue]>0);
 assert([engine enableClass:@"LXFixture" selector:@"point:" classMethod:NO][@"error"]);
 assert([engine enableClass:@"LXFixture" selector:@"variadic:" classMethod:NO][@"error"]);
 assert([engine enableClass:@"NSString" selector:@"length" classMethod:NO][@"error"]);
 NSArray *selectors=@[@"ping",@"echo:",@"addOne:",@"invert:",@"scale:",@"doubleValue:",@"classValue"];
 NSMutableDictionary *original=[NSMutableDictionary new];
 for(NSString *sel in selectors) {
  BOOL c=[sel isEqual:@"classValue"];Method method=c?class_getClassMethod(LXFixture.class,NSSelectorFromString(sel)):class_getInstanceMethod(LXFixture.class,NSSelectorFromString(sel));
  original[sel]=[NSValue valueWithPointer:method_getImplementation(method)];
  assert(!LXHookReason(@"LXFixture",sel,c,@(method_getTypeEncoding(method))));
  assert(![engine enableClass:@"LXFixture" selector:sel classMethod:c][@"error"]);
  assert(![engine enableClass:@"LXFixture" selector:sel classMethod:c][@"error"]);
 }
 [f ping];assert(f.pings==1);id marker=[NSObject new];assert([f echo:marker]==marker);
 assert([f addOne:41]==42);assert([f invert:NO]);assert([f scale:2]==3);assert([f doubleValue:2.5]==5);assert([LXFixture classValue]==42);
 NSArray *logs=[engine logs];assert(logs.count==7);
 for(NSDictionary *event in logs) { assert(event[@"arguments"] && event[@"return"] && event[@"encoding"] && event[@"thread"] && event[@"time"] && event[@"durationNs"]); }
 for(NSString *sel in selectors) { BOOL c=[sel isEqual:@"classValue"];NSString *key=[NSString stringWithFormat:@"%@LXFixture/%@",c?@"+":@"-",sel];assert(![engine disableKey:key][@"error"]);
  Method method=c?class_getClassMethod(LXFixture.class,NSSelectorFromString(sel)):class_getInstanceMethod(LXFixture.class,NSSelectorFromString(sel));assert(method_getImplementation(method)==[original[sel] pointerValue]);
 }
 assert([f addOne:41]==42);[f ping];assert(f.pings==2);assert([engine logs].count==7);
 assert(![engine enableClass:@"LXFixture" selector:@"addOne:" classMethod:NO][@"error"]);
 for(int i=0;i<1500;i++) assert([f addOne:i]==i+1);assert([engine logs].count<=1000);
 Method m=class_getInstanceMethod(LXFixture.class,@selector(addOne:));IMP old=method_setImplementation(m,(IMP)LXForeign);
 assert([engine disableKey:@"-LXFixture/addOne:"][@"error"]);assert(method_getImplementation(m)==(IMP)LXForeign);
 assert([f addOne:1]==100);method_setImplementation(m,old);[engine disableAll];
 puts("runtime: scanner, 7 reviewed signatures, originals, arguments/return logs, restore, duplicate, unsupported and conflict tests passed");
 }return 0; }
