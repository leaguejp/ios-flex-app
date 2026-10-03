#import "LXAuth.h"
#import <CommonCrypto/CommonHMAC.h>
NSString *LXNewToken(void) { unsigned char bytes[16];arc4random_buf(bytes,sizeof(bytes));char hex[33];for(unsigned i=0;i<16;i++) snprintf(hex+i*2,3,"%02x",bytes[i]);return @(hex); }
NSString *LXProof(NSString *token,NSString *purpose,NSDictionary *body) {
 NSData *data=[NSJSONSerialization dataWithJSONObject:@{@"purpose":purpose,@"body":body} options:NSJSONWritingSortedKeys error:nil];
 if(token.length!=32 || !data) return nil;
 unsigned char digest[32];CCHmac(kCCHmacAlgSHA256,token.UTF8String,strlen(token.UTF8String),data.bytes,data.length,digest);
 char hex[65];for(unsigned i=0;i<32;i++) snprintf(hex+i*2,3,"%02x",digest[i]);return @(hex);
}
BOOL LXProofMatches(NSString *expected,id received) {
 if(expected.length!=64 || ![received isKindOfClass:NSString.class] || [received length]!=64) return NO;
 NSData *a=[expected dataUsingEncoding:NSASCIIStringEncoding],*b=[received dataUsingEncoding:NSASCIIStringEncoding];if(a.length!=64 || b.length!=64) return NO;
 const uint8_t *x=a.bytes,*y=b.bytes;uint8_t delta=0;for(unsigned i=0;i<64;i++) delta|=x[i]^y[i];return delta==0;
}
