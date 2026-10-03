#import "LXTypes.h"
#import <objc/runtime.h>
#include "../core/encoding.h"
#include <math.h>
NSArray *LXDescribeEncoding(NSString *s) {
 LXType t[128];size_t n=0;if(!lx_signature(s.UTF8String,t,128,&n)) return @[@{@"error":@"Unparseable encoding"}];
 NSMutableArray *out=[NSMutableArray new];
 for(size_t i=0;i<n;i++) { NSString *raw=[[NSString alloc] initWithBytes:s.UTF8String+t[i].start length:t[i].length encoding:NSUTF8StringEncoding];
  [out addObject:@{@"kind":@(lx_kind_name(t[i].kind)),@"encoding":raw ?: @"?",@"index":@(i)}]; }
 return out;
}
NSString *LXHookReason(NSString *name,NSString *sel,BOOL classMethod,NSString *encoding) {
 LXType t[16];size_t n=0;if(!lx_signature(encoding.UTF8String,t,16,&n)) return @"Unparseable encoding";
 for(size_t i=0;i<n;i++) if(t[i].kind=='{' || t[i].kind=='(' || t[i].kind=='[' || t[i].kind=='^' || t[i].kind=='?' || t[i].kind=='D' || t[i].kind=='b') return @"Aggregate, pointer or special ABI is unsupported";
 // Metadata cannot prove nonvariadic prototypes. Reviewed declarations are mandatory.
 NSString *boolean=[NSString stringWithFormat:@"%s%s",@encode(BOOL),@encode(BOOL)];
 NSString *expected=nil;
 if([name isEqual:@"LXFixture"]) {
#if !LX_HOST_FIXTURE_TESTS
  if(![NSBundle.mainBundle.bundleIdentifier isEqual:@"jp.league.runtimeatlas.fixture"]) return @"Fixture declarations are restricted to the fixture bundle";
#endif
  NSDictionary *approved=@{@"-ping":@"v",@"-echo:":@"@@",@"-addOne:":@"qq",@"-invert:":boolean,@"-scale:":@"ff",@"-doubleValue:":@"dd",@"+classValue":@"q"};
  NSString *key=[NSString stringWithFormat:@"%@%@",classMethod?@"+":@"-",sel];expected=approved[key];
 } else if(!classMethod && ([name isEqual:@"UIView"] || [name isEqual:@"UIViewController"])) {
  // SDK-reviewed declarations only; never authorize another class/override by shape alone.
  Class cls=objc_getClass(name.UTF8String);const char *image=cls?class_getImageName(cls):NULL;
  NSString *path=image?@(image):@"";
  if(![path hasSuffix:@"/System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore"] && ![path hasSuffix:@"/System/Library/Frameworks/UIKit.framework/UIKit"]) return @"Reviewed UIKit profile requires the system UIKit image";
  if([name isEqual:@"UIView"] && [sel isEqual:@"setHidden:"]) expected=[NSString stringWithFormat:@"v%s",@encode(BOOL)];
  if([name isEqual:@"UIView"] && [sel isEqual:@"setAlpha:"]) expected=@"vd"; // arm64 CGFloat is double, verified against SDK in CI.
  if([name isEqual:@"UIViewController"] && ([sel isEqual:@"viewWillAppear:"] || [sel isEqual:@"viewDidAppear:"])) expected=[NSString stringWithFormat:@"v%s",@encode(BOOL)];
 }
 if(!expected) return @"No reviewed nonvariadic prototype; browse only (see support matrix)";
 NSMutableString *shape=[NSMutableString new];for(size_t i=0;i<n;i++) if(i!=1 && i!=2) { if(t[i].length!=1) return @"Qualified or complex ABI is unsupported";[shape appendFormat:@"%c",t[i].kind]; }
 if(![shape isEqual:expected]) return @"Encoding differs from reviewed declaration";
 if(n!=3 && n!=4) return @"Only zero or one explicit argument supported";
 return nil;
}

NSString *LXStaticHookReason(NSString *bundle,NSString *name,NSString *selector,BOOL meta,NSString *encoding) {
 // Offline data does not authorize arbitrary prototypes or identify a system UIKit class.
 if(![bundle isEqual:@"jp.league.runtimeatlas.fixture"] || ![name isEqual:@"LXFixture"]) return @"No reviewed nonvariadic declaration for this bundle/class; browse only";
 NSDictionary *approved=@{@"-ping":@"v",@"-echo:":@"@@",@"-addOne:":@"qq",@"-invert:":@"BB",@"-scale:":@"ff",@"-doubleValue:":@"dd",@"+classValue":@"q"};
 NSString *expected=approved[[NSString stringWithFormat:@"%@%@",meta?@"+":@"-",selector]];
 LXType types[16];size_t count=0;if(!expected || !lx_signature(encoding.UTF8String,types,16,&count)) return @"No reviewed declaration or invalid encoding";
 NSMutableString *shape=[NSMutableString new];for(size_t i=0;i<count;i++) if(i!=1 && i!=2) { if(types[i].length!=1) return @"Complex ABI unsupported";[shape appendFormat:@"%c",types[i].kind]; }
 return [shape isEqual:expected]?nil:@"Encoding differs from reviewed arm64 declaration";
}
NSString *LXPatchReason(NSDictionary *patch,NSString *encoding) {
 if(![patch isKindOfClass:NSDictionary.class] || patch.count>2) return @"Expected argument / return scalar fields";
 NSArray *types=LXDescribeEncoding(encoding);
 for(NSString *field in patch) {
  NSUInteger index=[field isEqual:@"return"]?0:[field isEqual:@"argument"]?3:NSUIntegerMax;
  if(index>=types.count) return @"Unknown field or absent argument";
  NSString *type=types[index][@"encoding"];id value=patch[field];
  if(![value isKindOfClass:NSNumber.class] || !isfinite([value doubleValue])) return @"A finite JSON scalar number is required";
  BOOL valid=NO;
  if([type isEqual:@"B"] || [type isEqual:@"c"]) valid=[value doubleValue]==0 || [value doubleValue]==1;
  else if([type isEqual:@"q"]) { NSDecimalNumber *number=[NSDecimalNumber decimalNumberWithDecimal:[value decimalValue]];valid=[number compare:[NSDecimalNumber decimalNumberWithString:@"-9223372036854775808"]]!=NSOrderedAscending && [number compare:[NSDecimalNumber decimalNumberWithString:@"9223372036854775807"]]!=NSOrderedDescending && [number compare:[NSDecimalNumber decimalNumberWithString:[value stringValue]]]==NSOrderedSame && floor([value doubleValue])==[value doubleValue]; }
  else if([type isEqual:@"f"]) valid=isfinite([value floatValue]);
  else if([type isEqual:@"d"]) valid=YES;
  if(!valid) return @"Only BOOL, signed 64-bit integer, float and double fields within range can be patched";
 }return nil;
}
