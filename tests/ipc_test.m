#import <Foundation/Foundation.h>
#import "../shared/LXChannel.h"
#import "../shared/LXProtocol.h"
#import "../shared/LXAuth.h"
#include <assert.h>
int main(int argc,char **argv) { @autoreleasepool {
 assert(!LXValidate(@{}));NSMutableDictionary *bad=[LXMessage(@"ping",@{}) mutableCopy];bad[@"version"]=@999;assert(!LXValidate(bad));
 NSString *token=LXNewToken();assert(token.length==32);NSDictionary *body=@{@"nonce":@"abc"};NSString *proof=LXProof(token,@"client",body);assert(LXProofMatches(proof,proof));assert(!LXProofMatches(proof,LXProof(token,@"server",body)));assert(!LXProofMatches(proof,LXProof(LXNewToken(),@"client",body)));assert(!LXProofMatches(proof,@"invalid"));
 dispatch_semaphore_t done=dispatch_semaphore_create(0);
 if(argc>1 && !strcmp(argv[1],"peer")) {
  LXChannel *c=[LXChannel connectLoopback:nil];assert(c);__weak LXChannel *weak=c;
  c.received=^(NSDictionary *m) { assert([m[@"command"] isEqual:@"pong"]);assert([m[@"responseID"] isEqual:@"test-command"]);
   assert([m[@"payload"][@"echo"] isEqual:@"sandbox-feasibility"]);[weak close];dispatch_semaphore_signal(done); };
  [c start];NSMutableDictionary *ping=[LXMessage(@"ping",@{@"echo":@"sandbox-feasibility"}) mutableCopy];ping[@"commandID"]=@"test-command";assert([c send:ping]);
  assert(dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,10*NSEC_PER_SEC))==0);return 0;
 }
 LXListener *listener=[LXListener new];__block LXChannel *server;
 listener.accepted=^(LXChannel *c) { server=c;__weak LXChannel *weak=c;c.received=^(NSDictionary *m) {
  NSMutableDictionary *r=[LXMessage(@"pong",m[@"payload"]) mutableCopy];r[@"responseID"]=m[@"commandID"];assert([weak send:r]); };
  [c start]; };
 assert([listener start:nil]);NSTask *peer=[NSTask new];peer.executableURL=[NSURL fileURLWithPath:@(argv[0])];peer.arguments=@[@"peer"];assert([peer launchAndReturnError:nil]);[peer waitUntilExit];assert(peer.terminationStatus==0);
 [server close];[listener stop];puts("IPC: production framed JSON round trip between separate macOS processes passed (NOT iOS sandbox proof)");
 }return 0; }
