#import "LXChannel.h"
#import "LXProtocol.h"
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <errno.h>
static BOOL LXRead(int fd,void *bytes,size_t count) {
 uint8_t *p=bytes;
 while(count) { ssize_t n=recv(fd,p,count,0);if(n<0 && errno==EINTR) continue;if(n<=0) return NO;p+=n;count-=(size_t)n; }
 return YES;
}
static NSError *LXSocketError(void) { return [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil]; }
@implementation LXChannel { int _fd; BOOL _started; BOOL _closed; NSLock *_writeLock; }
- (instancetype)initWithSocket:(int)fd {
 if((self=[super init])) { _fd=fd;_writeLock=[NSLock new];int one=1;setsockopt(fd,SOL_SOCKET,SO_NOSIGPIPE,&one,sizeof(one));
  struct timeval timeout={15,0};setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof(timeout));setsockopt(fd,SOL_SOCKET,SO_SNDTIMEO,&timeout,sizeof(timeout)); }
 return self;
}
- (BOOL)closed { @synchronized(self) { return _closed; } }
- (void)start {
 @synchronized(self) { if(_started) return;_started=YES; }
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
  int fd;@synchronized(self) { fd=self->_fd; }
  while(fd>=0 && !self.closed) { @autoreleasepool {
   uint32_t networkLength;
   if(!LXRead(fd,&networkLength,4)) break;
   uint32_t length=ntohl(networkLength);if(!length || length>LXMaxFrame) break;
   NSMutableData *data=[NSMutableData dataWithLength:length];if(!LXRead(fd,data.mutableBytes,length)) break;
   id m=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];if(!LXValidate(m)) break;
   if(self.received) self.received(m);
  }}
  [self close];if(self.disconnected) self.disconnected();
 });
}
- (BOOL)send:(NSDictionary *)m {
 if(!LXValidate(m)) return NO;
 NSData *data=[NSJSONSerialization dataWithJSONObject:m options:0 error:nil];if(!data || data.length>LXMaxFrame) return NO;
 [_writeLock lock];int fd;@synchronized(self) { fd=_closed?-1:_fd; }
 uint32_t length=htonl((uint32_t)data.length);NSMutableData *frame=[NSMutableData dataWithBytes:&length length:4];[frame appendData:data];
 const uint8_t *p=frame.bytes;size_t left=frame.length;BOOL ok=fd>=0;
 while(ok && left) { ssize_t n=send(fd,p,left,0);if(n<0 && errno==EINTR) continue;if(n<=0) { ok=NO;break; }p+=n;left-=(size_t)n; }
 [_writeLock unlock];if(!ok) [self close];return ok;
}
- (void)close {
 // shutdown wakes reader; only reader/dealloc closes descriptor, avoiding fd reuse races.
 @synchronized(self) { _closed=YES;if(_fd>=0) shutdown(_fd,SHUT_RDWR); }
}
- (void)dealloc { if(_fd>=0) { shutdown(_fd,SHUT_RDWR);close(_fd); } }
+ (instancetype)connectLoopback:(NSError **)error {
 int fd=socket(AF_INET,SOCK_STREAM,0);if(fd<0) { if(error)*error=LXSocketError();return nil; }
 struct sockaddr_in addr={0};addr.sin_family=AF_INET;addr.sin_port=htons(LXPort);addr.sin_addr.s_addr=htonl(INADDR_LOOPBACK);
 if(connect(fd,(struct sockaddr *)&addr,sizeof(addr))) { if(error)*error=LXSocketError();close(fd);return nil; }
 return [[self alloc] initWithSocket:fd];
}
@end
@implementation LXListener { int _fd; BOOL _running; }
- (BOOL)start:(NSError **)error {
 _fd=socket(AF_INET,SOCK_STREAM,0);if(_fd<0) { if(error)*error=LXSocketError();return NO; }
 int one=1;setsockopt(_fd,SOL_SOCKET,SO_REUSEADDR,&one,sizeof(one));
 struct sockaddr_in addr={0};addr.sin_family=AF_INET;addr.sin_port=htons(LXPort);addr.sin_addr.s_addr=htonl(INADDR_LOOPBACK);
 if(bind(_fd,(struct sockaddr *)&addr,sizeof(addr)) || listen(_fd,16)) { if(error)*error=LXSocketError();close(_fd);_fd=-1;return NO; }
 _running=YES;int server=_fd;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
  while(self->_running) { int fd=accept(server,NULL,NULL);if(fd<0) break;
   LXChannel *channel=[[LXChannel alloc] initWithSocket:fd];if(self.accepted) self.accepted(channel);else [channel close]; }
 });return YES;
}
- (void)stop { _running=NO;if(_fd>=0) { shutdown(_fd,SHUT_RDWR);close(_fd);_fd=-1; } }
@end
