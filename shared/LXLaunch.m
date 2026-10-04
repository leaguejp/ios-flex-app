#import "LXLaunch.h"
#import "LXAuth.h"
#import "LXProtocol.h"
#include <math.h>
#import <CommonCrypto/CommonDigest.h>
static NSString * const LXTicketPrefix=@"RuntimeAtlasAnalysis:";
NSString *LXAnalysisTicket(NSString *bundle,NSString *token,NSString *requestID) {
 NSDictionary *body=@{@"version":@1,@"bundle":bundle,@"token":token,@"requestID":requestID,@"expiresAt":@(NSDate.date.timeIntervalSince1970+90)};
 NSData *data=[NSJSONSerialization dataWithJSONObject:body options:0 error:nil];return [LXTicketPrefix stringByAppendingString:[data base64EncodedStringWithOptions:0]];
}
NSDictionary *LXReadAnalysisTicket(NSString *text,NSString *bundle,NSTimeInterval now) {
 if(![text isKindOfClass:NSString.class] || text.length>2048 || ![text hasPrefix:LXTicketPrefix]) return nil;
 NSData *data=[[NSData alloc] initWithBase64EncodedString:[text substringFromIndex:LXTicketPrefix.length] options:0];
 id body=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
 if(![body isKindOfClass:NSDictionary.class] || ![body[@"version"] isKindOfClass:NSNumber.class] || [body[@"version"] doubleValue]!=1 || ![body[@"bundle"] isEqual:bundle]) return nil;
 NSString *token=body[@"token"],*request=body[@"requestID"];id expiry=body[@"expiresAt"];
 if(![token isKindOfClass:NSString.class] || token.length!=32 || [token rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"].invertedSet].location!=NSNotFound || ![request isKindOfClass:NSString.class] || ![[NSUUID alloc] initWithUUIDString:request] || ![expiry isKindOfClass:NSNumber.class] || !isfinite([expiry doubleValue]) || [expiry doubleValue]<=now || [expiry doubleValue]>now+90.5) return nil;
 return body;
}
NSURL *LXAnalysisReturnURL(NSString *requestID) {
 if(![[NSUUID alloc] initWithUUIDString:requestID]) return nil;
 NSURLComponents *url=[NSURLComponents new];url.scheme=@"runtimeatlas";url.host=@"analysis";url.queryItems=@[[NSURLQueryItem queryItemWithName:@"requestID" value:requestID]];return url.URL;
}

NSString *LXAnalysisPasteboardType(NSString *bundle) {
 NSData *data=[bundle dataUsingEncoding:NSUTF8StringEncoding];unsigned char digest[CC_SHA256_DIGEST_LENGTH];CC_SHA256(data.bytes,(CC_LONG)data.length,digest);char hex[65];for(unsigned i=0;i<32;i++) snprintf(hex+i*2,3,"%02x",digest[i]);
 return [@"jp.league.runtimeatlas.analysis-ticket." stringByAppendingString:@(hex)];
}

NSString *LXAnalysisResultPasteboardType(NSString *bundle) { return [LXAnalysisPasteboardType(bundle) stringByReplacingOccurrencesOfString:@"analysis-ticket." withString:@"analysis-result."]; }
NSData *LXAnalysisResult(NSDictionary *catalog,NSString *failure,NSDictionary *ticket) {
 NSDictionary *body=@{@"version":@1,@"bundle":ticket[@"bundle"],@"requestID":ticket[@"requestID"],@"expiresAt":ticket[@"expiresAt"],@"catalog":catalog ?: (id)NSNull.null,@"error":failure ?: (id)NSNull.null};
 NSString *proof=LXProof(ticket[@"token"],@"analysis-result",body);if(!proof) return nil;
 NSMutableDictionary *envelope=[body mutableCopy];envelope[@"proof"]=proof;
 NSData *data=[NSJSONSerialization dataWithJSONObject:envelope options:NSJSONWritingSortedKeys error:nil];return data.length<=8*1024*1024?data:nil;
}
NSDictionary *LXReadAnalysisResult(NSData *data,NSString *bundle,NSString *request,NSString *token,NSTimeInterval now) {
 if(![data isKindOfClass:NSData.class] || !data.length || data.length>8*1024*1024) return nil;
 id value=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];if(![value isKindOfClass:NSDictionary.class]) return nil;
 NSMutableDictionary *body=[value mutableCopy];id proof=body[@"proof"];[body removeObjectForKey:@"proof"];
 id version=body[@"version"],expiry=body[@"expiresAt"];
 if(![version isKindOfClass:NSNumber.class] || [version doubleValue]!=1 || ![body[@"bundle"] isEqual:bundle] || ![body[@"requestID"] isEqual:request] || ![expiry isKindOfClass:NSNumber.class] || !isfinite([expiry doubleValue]) || [expiry doubleValue]<=now || [expiry doubleValue]>now+90.5 || !LXProofMatches(LXProof(token,@"analysis-result",body),proof)) return nil;
 if(body[@"error"]!=NSNull.null) { if(![body[@"error"] isKindOfClass:NSString.class] || [body[@"error"] length]>2048 || body[@"catalog"]!=NSNull.null) return nil; }
 else { NSDictionary *catalog=body[@"catalog"];if(LXRuntimeCatalogReason(catalog) || ![catalog[@"bundle"] isEqual:bundle] || ![catalog[@"requestID"] isEqual:request]) return nil; }
 return body;
}
