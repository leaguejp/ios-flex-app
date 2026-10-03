#import <Foundation/Foundation.h>
#define LXProtocolVersion 1
#define LXPort 49371
#define LXMaxFrame (4 * 1024 * 1024)
NSDictionary *LXMessage(NSString *command, NSDictionary *payload);
BOOL LXValidate(NSDictionary *message);
NSDictionary *LXError(NSString *code, NSString *detail);
