#import <Foundation/Foundation.h>
NSString *LXAnalysisTicket(NSString *bundle,NSString *token,NSString *requestID);
NSDictionary *LXReadAnalysisTicket(NSString *text,NSString *bundle,NSTimeInterval now);
NSURL *LXAnalysisReturnURL(NSString *requestID);

NSString *LXAnalysisPasteboardType(NSString *bundle);
