#include "../core/encoding.h"
#include "../core/macho.h"
#include <assert.h>
#include <string.h>
#include <stdio.h>
static int emissions;
static void emit(void *ctx,const char *k,const char *v) { (void)ctx;(void)k;(void)v;emissions++; }
static void put(unsigned char *d,unsigned x) { d[0]=x;d[1]=x>>8;d[2]=x>>16;d[3]=x>>24; }
static void put64(unsigned char *d,uint64_t x) { put(d,(unsigned)x);put(d+4,(unsigned)(x>>32)); }
static unsigned classes,instance_methods,class_methods;
static void objc_emit(void *ctx,const char *name,int meta,const char *sel,const char *encoding) {
 (void)ctx;assert(!strcmp(name,"LXFixture"));if(!sel) classes++;else { assert(!strcmp(sel,meta?"classValue":"addOne:"));assert(!strcmp(encoding,meta?"q16@0:8":"q24@0:8q16"));if(meta) class_methods++;else instance_methods++; }
}
static void objc_test(void) {
 unsigned char d[2048]={0};char e[128]={0};uint64_t base=UINT64_C(0x100000000);
 put(d,0xfeedfacf);put(d+4,0x100000c);put(d+16,1);put(d+20,152);
 put(d+32,0x19);put(d+36,152);put64(d+56,base);put64(d+64,sizeof(d));put64(d+72,0);put64(d+80,sizeof(d));put(d+96,1);
 memcpy(d+104,"__objc_classlist",16);put64(d+136,base+256);put64(d+144,8);put(d+152,256);
 unsigned slots[]={256,320,352,416,472,480,560,616,624,680,688};unsigned targets[]={320,384,448,528,736,608,672,768,800,832,864};
 for(unsigned i=0;i<sizeof(slots)/sizeof(*slots);i++) put64(d+slots[i],base+targets[i]);
 put(d+608,24);put(d+612,1);put(d+672,24);put(d+676,1);
 strcpy((char *)d+736,"LXFixture");strcpy((char *)d+768,"addOne:");strcpy((char *)d+800,"q24@0:8q16");strcpy((char *)d+832,"classValue");strcpy((char *)d+864,"q16@0:8");
 assert(lx_macho_objc(d,sizeof(d),objc_emit,NULL,e,sizeof(e)));assert(classes==1 && instance_methods==1 && class_methods==1);
 // Small relative lists with direct selector strings, including negative offset rejection.
 put(d+608,0xc000000c);put(d+616,768-616);put(d+620,800-620);
 assert(lx_macho_objc(d,sizeof(d),objc_emit,NULL,e,sizeof(e)));assert(classes==2 && instance_methods==2 && class_methods==2);
 put(d+616,0x80000000);assert(!lx_macho_objc(d,sizeof(d),objc_emit,NULL,e,sizeof(e)));
 put(d+608,24);put64(d+616,base+768);put64(d+624,base+800);
 // Chained PTR_64_OFFSET: only chain-marked pointer slots may be decoded.
 put(d+16,2);put(d+20,168);put(d+184,0x80000034);put(d+188,16);put(d+192,1024);put(d+196,60);
 put(d+1028,28);put(d+1052,1);put(d+1056,8);put(d+1060,24);d[1064]=0;d[1065]=16;d[1066]=6;put64(d+1068,0);d[1080]=1;d[1082]=0;d[1083]=1;
 for(unsigned i=0;i<sizeof(slots)/sizeof(*slots);i++) { uint64_t next=i+1<sizeof(slots)/sizeof(*slots)?(slots[i+1]-slots[i])/4:0;put64(d+slots[i],targets[i]|(next<<51)); }
 assert(lx_macho_objc(d,sizeof(d),objc_emit,NULL,e,sizeof(e)));
 d[1066]=12;assert(!lx_macho_objc(d,sizeof(d),objc_emit,NULL,e,sizeof(e)) && !strcmp(e,"unsupported_chained_pointer_format"));d[1066]=6;
 put64(d+256,UINT64_C(1)<<63);assert(!lx_macho_objc(d,sizeof(d),objc_emit,NULL,e,sizeof(e)));
 for(size_t i=0;i<200;i++) assert(!lx_macho_objc(d,i,objc_emit,NULL,e,sizeof(e)));
}
int main(void) {
 objc_test();LXType t[32];size_t n;
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
 put(d+32,0xdeadbeef);assert(!lx_macho(d,56,emit,NULL,e,sizeof(e))&&!strcmp(e,"unknown_load_command"));
 unsigned state=0x12345678;
 for(unsigned iteration=0;iteration<20000;iteration++) {
  for(size_t j=0;j<sizeof(d);j++) { state=state*1664525u+1013904223u;d[j]=(unsigned char)(state>>24); }
  if(iteration%2==0) put(d,0xfeedfacf);
  (void)lx_macho(d,iteration%sizeof(d),emit,NULL,e,sizeof(e));
  (void)lx_macho_objc(d,iteration%sizeof(d),objc_emit,NULL,e,sizeof(e));
 }
 puts("core: encoding, classic/relative/chained static Objective-C relationships and malformed Mach-O tests passed");return 0;
}
