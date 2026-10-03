#include "macho.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
static uint32_t u32(const uint8_t *p,int swap) {
 return swap?((uint32_t)p[0]<<24)|((uint32_t)p[1]<<16)|((uint32_t)p[2]<<8)|p[3]:
 ((uint32_t)p[3]<<24)|((uint32_t)p[2]<<16)|((uint32_t)p[1]<<8)|p[0];
}
static uint64_t u64(const uint8_t *p,int swap) { return swap?((uint64_t)u32(p,1)<<32)|u32(p+4,1):((uint64_t)u32(p+4,0)<<32)|u32(p,0); }
static int fail(char *e,size_t n,const char *s) { if(n) snprintf(e,n,"%s",s); return 0; }
static int range(uint64_t off,uint64_t size,size_t n) { return off<=n && size<=n-off; }
static int thin(const uint8_t *d,size_t n,LXEmit emit,void *ctx,char *err,size_t es) {
 if(n<32) return fail(err,es,"truncated_header");
 uint32_t magic=u32(d,0); int swap=magic==0xcffaedfe;
 if(magic!=0xfeedfacf && !swap) return fail(err,es,"unsupported_magic_or_32bit");
 uint32_t cpu=u32(d+4,swap),commands=u32(d+16,swap),bytes=u32(d+20,swap);
 if(commands>65536 || !range(32,bytes,n)) return fail(err,es,"invalid_load_commands");
 char val[256];snprintf(val,sizeof(val),"0x%x",cpu);emit(ctx,"architecture",val);
 size_t p=32,end=32+bytes;
 for(uint32_t i=0;i<commands;i++) {
  if(p>end || end-p<8) return fail(err,es,"truncated_command");
  uint32_t cmd=u32(d+p,swap),size=u32(d+p+4,swap);
  if(size<8 || size%8 || size>end-p) return fail(err,es,"invalid_command_size");
  if(cmd==0x1b) {
   if(size<24) return fail(err,es,"truncated_uuid");
   for(int j=0;j<16;j++) snprintf(val+j*2,3,"%02x",d[p+8+j]);emit(ctx,"uuid",val);
  } else if(cmd==0x21 || cmd==0x2c) {
   if(size<(cmd==0x2c?24u:20u)) return fail(err,es,"truncated_encryption");
   if(u32(d+p+16,swap)) return fail(err,es,"encrypted_image");
  } else if(cmd==0xc || cmd==0x80000018 || cmd==0x8000001f || cmd==0x80000023) {
   if(size<24) return fail(err,es,"truncated_dylib");
   uint32_t off=u32(d+p+8,swap);
   if(off<24 || off>=size || !memchr(d+p+off,0,size-off)) return fail(err,es,"invalid_dylib_name");
   emit(ctx,"dependency",(const char *)d+p+off);
  } else if(cmd==0x19) {
   if(size<72) return fail(err,es,"truncated_segment");
   uint32_t sections=u32(d+p+64,swap);
   if(sections>(size-72)/80) return fail(err,es,"invalid_sections");
   for(uint32_t j=0;j<sections;j++) {
    const uint8_t *s=d+p+72+j*80;char name[17];memcpy(name,s,16);name[16]=0;
    uint64_t len=u64(s+40,swap);uint32_t off=u32(s+48,swap);
    const char *key=!strcmp(name,"__objc_classname")?"objc_classname":!strcmp(name,"__objc_methname")?"objc_selector":!strcmp(name,"__objc_methtype")?"objc_encoding":NULL;
    if(key) {
     if(!range(off,len,n)) return fail(err,es,"invalid_objc_section");
     size_t x=off,limit=off+(size_t)len;unsigned emitted=0;
     while(x<limit) { const uint8_t *z=memchr(d+x,0,limit-x);if(!z) return fail(err,es,"unterminated_objc_string");
      if(z>d+x && emitted++<20000) emit(ctx,key,(const char *)d+x);x=(size_t)(z-d)+1;
     }
    }
   }
  } else {
   // Preserve known-but-uninterpreted load commands; reject future/unknown IDs structurally.
   uint32_t base=cmd & 0x7fffffffu;
   if(base==0 || base>0x38) return fail(err,es,"unknown_load_command");
   snprintf(val,sizeof(val),"0x%x",cmd);emit(ctx,"load_command",val);
   if(cmd==0x80000034) emit(ctx,"limitation","chained_fixups_not_resolved");
  }
  p+=size;
 }
 if(p!=end) return fail(err,es,"command_count_mismatch");
 emit(ctx,"provenance","Static Only");return 1;
}
int lx_macho(const uint8_t *d,size_t n,LXEmit emit,void *ctx,char *e,size_t es) {
 if(!d || !emit || n<4) return fail(e,es,"truncated_header");
 uint32_t m=u32(d,1);
 if(m==0xcafebabe || m==0xcafebabf) {
  if(n<8) return fail(e,es,"truncated_fat");
  uint32_t count=u32(d+4,1);size_t stride=m==0xcafebabf?32:20;
  if(!count || count>64 || count>(n-8)/stride) return fail(e,es,"invalid_fat_table");
  for(uint32_t i=0;i<count;i++) {
   const uint8_t *a=d+8+i*stride;uint64_t off=stride==32?u64(a+8,1):u32(a+8,1),len=stride==32?u64(a+16,1):u32(a+12,1);
   if(off<8+count*stride || !range(off,len,n)) return fail(e,es,"invalid_fat_slice");
   if(!thin(d+(size_t)off,(size_t)len,emit,ctx,e,es)) return 0;
  }return 1;
 }
 return thin(d,n,emit,ctx,e,es);
}
#include "objc_metadata.inc"
