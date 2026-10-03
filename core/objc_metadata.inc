/* Independent file-only decoder. ABI references are documented in architecture.md.
 * No runtime addresses are dereferenced, no IMP is interpreted as executable code. */
typedef struct { uint64_t vm, file, size; } LXSegment;
typedef struct { uint64_t slot, target; } LXFixup;
typedef struct {
 const uint8_t *d;size_t n;LXSegment seg[128];unsigned segments;
 uint64_t base;LXFixup *fix;size_t fixes;LXObjCEmit emit;void *ctx;
} LXMetadata;
static uint16_t le16(const uint8_t *d) { return (uint16_t)(d[0]|d[1]<<8); }
static int mapped(LXMetadata *m,uint64_t vm,size_t bytes,size_t *off) {
 for(unsigned i=0;i<m->segments;i++) { LXSegment *s=&m->seg[i];
  if(vm>=s->vm && vm-s->vm<=s->size && bytes<=s->size-(vm-s->vm) && range(s->file+(vm-s->vm),bytes,m->n)) {
   *off=(size_t)(s->file+vm-s->vm);return 1;
  }
 }return 0;
}
static int fixcmp(const void *a,const void *b) {
 uint64_t x=((const LXFixup *)a)->slot,y=((const LXFixup *)b)->slot;return x<y?-1:x>y;
}
static int pointer(LXMetadata *m,uint64_t slot,uint64_t *target) {
 size_t off;if(!mapped(m,slot,8,&off)) return 0;
 LXFixup key={slot,0};LXFixup *f=m->fixes?bsearch(&key,m->fix,m->fixes,sizeof(*m->fix),fixcmp):NULL;
 *target=f?f->target:u64(m->d+off,0);return !f || f->target!=UINT64_MAX;
}
static const char *cstring(LXMetadata *m,uint64_t vm) {
 size_t off;if(!mapped(m,vm,1,&off)) return NULL;
 size_t length=0;while(length<16384 && mapped(m,vm,length+1,&off)) {
  if(!m->d[off+length]) return (const char *)m->d+off;length++;
 }return NULL;
}
static int relative(uint64_t address,uint32_t encoded,uint64_t *target) {
 int64_t delta=(int32_t)encoded;
 if(delta<0) { uint64_t magnitude=(uint64_t)(-delta);if(address<magnitude) return 0;*target=address-magnitude; }
 else { if(address>UINT64_MAX-(uint64_t)delta) return 0;*target=address+(uint64_t)delta; }return 1;
}
static int methods(LXMetadata *m,uint64_t list,const char *name,int meta,char *e,size_t es) {
 if(!list) return 1;size_t off;if(!mapped(m,list,8,&off)) return fail(e,es,"invalid_method_list");
 uint32_t flags=u32(m->d+off,0),count=u32(m->d+off+4,0),stride=flags&0xfffcu;
 int small=(flags&0x80000000u)!=0;
 if(count>20000 || stride!=(small?12u:24u) || !mapped(m,list,8+(size_t)count*stride,&off)) return fail(e,es,"unsupported_method_list");
 for(uint32_t i=0;i<count;i++) {
  uint64_t entry=list+8+(uint64_t)i*stride,sel=0,type=0;size_t x;
  if(small) {
   if(!mapped(m,entry,12,&x) || !relative(entry,u32(m->d+x,0),&sel) || !relative(entry+4,u32(m->d+x+4,0),&type)) return fail(e,es,"invalid_relative_method");
   if(!(flags&0x40000000u) && !pointer(m,sel,&sel)) return fail(e,es,"unresolved_selector_reference");
  } else if(!pointer(m,entry,&sel) || !pointer(m,entry+8,&type)) return fail(e,es,"unresolved_method_pointer");
  const char *selector=cstring(m,sel),*encoding=cstring(m,type);
  if(!selector || !encoding || !*selector || !*encoding) return fail(e,es,"invalid_method_strings");
  m->emit(m->ctx,name,meta,selector,encoding);
 }return 1;
}
static int rodata(LXMetadata *m,uint64_t cls,uint64_t *ro) {
 if(cls>UINT64_MAX-32 || !pointer(m,cls+32,ro)) return 0;*ro&=~UINT64_C(7);size_t off;return mapped(m,*ro,72,&off);
}
static int classinfo(LXMetadata *m,uint64_t cls,char *e,size_t es) {
 uint64_t ro=0,nameptr=0,list=0,meta=0;
 if(!rodata(m,cls,&ro) || !pointer(m,ro+24,&nameptr) || !pointer(m,ro+32,&list)) return fail(e,es,"unresolved_class_metadata");
 const char *name=cstring(m,nameptr);if(!name || !*name) return fail(e,es,"invalid_class_name");
 m->emit(m->ctx,name,0,NULL,NULL);if(!methods(m,list,name,0,e,es)) return 0;
 if(!pointer(m,cls,&meta) || !meta || !rodata(m,meta,&ro) || !pointer(m,ro+32,&list)) return fail(e,es,"unresolved_metaclass");
 return methods(m,list,name,1,e,es);
}
static int chains(LXMetadata *m,uint32_t file,uint32_t length,char *e,size_t es) {
 if(!range(file,length,m->n) || length<28 || u32(m->d+file,0)!=0) return fail(e,es,"invalid_fixup_header");
 uint32_t start=u32(m->d+file+4,0);if(start>length-4) return fail(e,es,"invalid_fixup_starts");
 const uint8_t *d=m->d+file+start;size_t available=length-start;uint32_t count=u32(d,0);
 if(count>m->segments || count>(available-4)/4) return fail(e,es,"invalid_fixup_segments");
 m->fix=calloc(100000,sizeof(*m->fix));if(!m->fix) return fail(e,es,"allocation_failed");
 for(uint32_t i=0;i<count;i++) {
  uint32_t o=u32(d+4+i*4,0);if(!o) continue;
  if(o<4+count*4 || !range(o,22,available)) return fail(e,es,"invalid_fixup_segment");
  uint32_t size=u32(d+o,0);uint16_t page=le16(d+o+4),format=le16(d+o+6),pages=le16(d+o+20);
  uint64_t vmoffset=u64(d+o+8,0);
  if(size<22 || !range(o,size,available) || pages>(size-22)/2 || (page!=4096 && page!=16384)) return fail(e,es,"invalid_fixup_pages");
  if(format!=2 && format!=6) return fail(e,es,"unsupported_chained_pointer_format");
  if(vmoffset>UINT64_MAX-m->base || m->base+vmoffset!=m->seg[i].vm) return fail(e,es,"invalid_fixup_vm_offset");
  for(uint16_t j=0;j<pages;j++) {
   uint16_t first=le16(d+o+22+j*2);if(first==0xffff) continue;
   if(first&0x8000) return fail(e,es,"unsupported_multiple_chain_starts");
   if(first>=page) return fail(e,es,"invalid_chain_start");
   uint64_t pagevm=m->seg[i].vm+(uint64_t)j*page,slot=pagevm+first;
   for(unsigned step=0;step<page/4;step++) {
    size_t x;if(slot<pagevm || slot-pagevm>page-8u || !mapped(m,slot,8,&x) || m->fixes>=100000) return fail(e,es,"invalid_or_excessive_chain");
    uint64_t bits=u64(m->d+x,0),target=UINT64_MAX;
    if(!(bits>>63)) {
     if((bits>>44)&127) return fail(e,es,"invalid_chain_reserved_bits");
     target=bits&UINT64_C(0xfffffffff);uint64_t high=(bits>>36)&255;
     if(format==6) { if(target>UINT64_MAX-m->base || high) return fail(e,es,"unsupported_high_chain_target");target+=m->base; }
     else target|=high<<56;
    }
    m->fix[m->fixes++]=(LXFixup){slot,target};uint64_t next=((bits>>51)&4095)*4;
    if(!next) break;if(next>page || slot>UINT64_MAX-next) return fail(e,es,"invalid_chain_next");slot+=next;
   }
  }
 }
 qsort(m->fix,m->fixes,sizeof(*m->fix),fixcmp);return 1;
}
int lx_macho_objc(const uint8_t *d,size_t n,LXObjCEmit emit,void *ctx,char *e,size_t es) {
 if(!d || !emit || n<32) return fail(e,es,"truncated_objc_header");
 uint32_t fat=u32(d,1);
 if(fat==0xcafebabe || fat==0xcafebabf) {
  uint32_t count=u32(d+4,1);size_t stride=fat==0xcafebabf?32:20;
  if(count>64 || count>(n-8)/stride) return fail(e,es,"invalid_fat_table");
  for(uint32_t i=0;i<count;i++) { const uint8_t *a=d+8+i*stride;
   if(u32(a,1)!=0x100000c) continue;
   uint64_t off=stride==32?u64(a+8,1):u32(a+8,1),len=stride==32?u64(a+16,1):u32(a+12,1);
   if(off<8+count*stride || !range(off,len,n)) return fail(e,es,"invalid_fat_slice");
   return lx_macho_objc(d+off,(size_t)len,emit,ctx,e,es);
  }return fail(e,es,"no_arm64_slice");
 }
 if(u32(d,0)!=0xfeedfacf || u32(d+4,0)!=0x100000c || (u32(d+8,0)&0xffffff)==2) return fail(e,es,"unsupported_objc_architecture");
 LXMetadata m={0};m.d=d;m.n=n;m.emit=emit;m.ctx=ctx;
 uint32_t commands=u32(d+16,0),bytes=u32(d+20,0);size_t p=32;
 if(commands>65536 || !range(32,bytes,n)) return fail(e,es,"invalid_load_commands");
 uint64_t lists[128],sizes[128];unsigned listcount=0;uint32_t fixfile=0,fixsize=0;int result=0;
 for(uint32_t i=0;i<commands;i++) {
  if(p>32+bytes || 32+bytes-p<8) { fail(e,es,"truncated_command");goto done; }
  uint32_t cmd=u32(d+p,0),size=u32(d+p+4,0);
  if(size<8 || size%8 || size>32+bytes-p) { fail(e,es,"invalid_command_size");goto done; }
  if(cmd==0x2c || cmd==0x21) { if(size<24 || u32(d+p+16,0)) { fail(e,es,"encrypted_or_invalid_image");goto done; } }
  if(cmd==0x80000034) { if(size<16 || fixsize) { fail(e,es,"invalid_fixup_command");goto done; }fixfile=u32(d+p+8,0);fixsize=u32(d+p+12,0); }
  if(cmd==0x19) {
   if(size<72 || m.segments>=128) { fail(e,es,"invalid_segment");goto done; }
   LXSegment seg={u64(d+p+24,0),u64(d+p+40,0),u64(d+p+48,0)};
   if(!range(seg.file,seg.size,n) || seg.vm>UINT64_MAX-seg.size) { fail(e,es,"invalid_segment_range");goto done; }
   m.seg[m.segments++]=seg;if(seg.file==0 && seg.size) m.base=seg.vm;
   uint32_t sections=u32(d+p+64,0);if(sections>(size-72)/80) { fail(e,es,"invalid_sections");goto done; }
   for(uint32_t j=0;j<sections;j++) { const uint8_t *s=d+p+72+j*80;
    if(!memcmp(s,"__objc_classlist\0",16)) { if(listcount>=128) { fail(e,es,"classlist_limit");goto done; }lists[listcount]=u64(s+32,0);sizes[listcount++]=u64(s+40,0); }
   }
  }p+=size;
 }
 if(p!=32+bytes) { fail(e,es,"command_count_mismatch");goto done; }
 if(fixsize && !chains(&m,fixfile,fixsize,e,es)) goto done;
 for(unsigned i=0;i<listcount;i++) {
  size_t off;if(sizes[i]%8 || sizes[i]/8>20000 || !mapped(&m,lists[i],(size_t)sizes[i],&off)) { fail(e,es,"invalid_classlist");goto done; }
  for(uint64_t j=0;j<sizes[i];j+=8) { uint64_t cls;if(!pointer(&m,lists[i]+j,&cls) || !classinfo(&m,cls,e,es)) { if(es && !*e) fail(e,es,"unresolved_class_pointer");goto done; } }
 }result=1;
done: free(m.fix);return result;
}
