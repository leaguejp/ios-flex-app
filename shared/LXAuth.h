#import <Foundation/Foundation.h>
NSString *LXProof(NSString *token,NSString *purpose,NSDictionary *body);
BOOL LXProofMatches(NSString *expected,id received);
NSString *LXNewToken(void);
