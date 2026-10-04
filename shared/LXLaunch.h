#import <Foundation/Foundation.h>
NSString *LXAnalysisTicket(NSString *bundle,NSString *token,NSString *requestID);
NSDictionary *LXReadAnalysisTicket(NSString *text,NSString *bundle,NSTimeInterval now);
NSURL *LXAnalysisReturnURL(NSString *requestID);

NSString *LXAnalysisPasteboardType(NSString *bundle);

NSString *LXAnalysisResultPasteboardType(NSString *bundle);
NSData *LXAnalysisResult(NSDictionary *catalog,NSString *failure,NSDictionary *ticket);
NSDictionary *LXReadAnalysisResult(NSData *data,NSString *bundle,NSString *request,NSString *token,NSTimeInterval now);
