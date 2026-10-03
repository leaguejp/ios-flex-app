#include "../core/encoding.h"
#include "../core/macho.h"
#include <assert.h>
#include <string.h>
#include <stdio.h>
static int emissions;
static void emit(void *ctx,const char *k,const char *v) { (void)ctx;(void)k;(void)v;emissions++; }
static void put(unsigned char *d,unsigned x) { d[0]=x;d[1]=x>>8;d[2]=x>>16;d[3]=x>>24; }
int main(void) {
 LXType t[32];size_t n;
 assert(lx_signature("v24@0:8@\"NSString\"16",t,32,&n)&&n==4&&t[3].kind=='@');
 assert(lx_signature("{Point=dd}32@0:8^{Outer=\"x\"[4i](U=fd)}16",t,32,&n));
 assert(lx_signature("v24@0:8@?16",t,32,&n));
 assert(lx_signature("B24@0:8B16",t,32,&n));
 assert(!lx_signature("v@:{x=",t,32,&n));assert(!lx_signature("v@:!",t,32,&n));
 assert(!lx_signature("v@:i",t,3,&n));assert(!lx_signature("v#:",t,32,&n));
 unsigned char d[128]={0};char e[128];put(d,0xfeedfacf);put(d+4,0x100000c);
 assert(lx_macho(d,32,emit,NULL,e,sizeof(e))&&emissions==2);
 put(d+16,1);put(d+20,24);put(d+32,0x1b);put(d+36,24);
 assert(lx_macho(d,56,emit,NULL,e,sizeof(e)));
 put(d+36,0xfffffff8);assert(!lx_macho(d,56,emit,NULL,e,sizeof(e)));
 put(d+36,24);put(d+32,0x2c);put(d+48,1);assert(!lx_macho(d,56,emit,NULL,e,sizeof(e))&&!strcmp(e,"encrypted_image"));
 for(size_t i=0;i<56;i++) assert(!lx_macho(d,i,emit,NULL,e,sizeof(e)));
 unsigned state=0x12345678;
 for(unsigned iteration=0;iteration<20000;iteration++) {
  for(size_t j=0;j<sizeof(d);j++) { state=state*1664525u+1013904223u;d[j]=(unsigned char)(state>>24); }
  if(iteration%2==0) put(d,0xfeedfacf);
  (void)lx_macho(d,iteration%sizeof(d),emit,NULL,e,sizeof(e));
 }
 puts("core: encoding and malformed Mach-O tests passed");return 0;
}
