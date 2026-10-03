#import "LXTypes.h"
#include "../core/encoding.h"
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
 if(![name isEqual:@"LXFixture"]) return @"No reviewed nonvariadic prototype; browse only (see support matrix)";
 NSString *boolean=[NSString stringWithFormat:@"%s%s",@encode(BOOL),@encode(BOOL)];
 NSDictionary *approved=@{@"-ping":@"v",@"-echo:":@"@@",@"-addOne:":@"qq",@"-invert:":boolean,@"-scale:":@"ff",@"-doubleValue:":@"dd",@"+classValue":@"q"};
 NSString *key=[NSString stringWithFormat:@"%@%@",classMethod?@"+":@"-",sel];NSString *expected=approved[key];
 if(!expected) return @"Prototype not in reviewed fixture manifest";
 NSMutableString *shape=[NSMutableString new];for(size_t i=0;i<n;i++) if(i!=1 && i!=2) { if(t[i].length!=1) return @"Qualified or complex ABI is unsupported";[shape appendFormat:@"%c",t[i].kind]; }
 if(![shape isEqual:expected]) return @"Encoding differs from reviewed declaration";
 if(n!=3 && n!=4) return @"Only zero or one explicit argument supported";
 return nil;
}
