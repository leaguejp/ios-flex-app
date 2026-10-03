#include "encoding.h"
#include <string.h>
#include <ctype.h>
static int quoted(const char *s,size_t *p) {
 if(s[*p]!='"') return 1;
 ++*p; while(s[*p] && s[*p]!='"') { if(s[*p]=='\\' && s[*p+1]) ++*p; ++*p; }
 if(!s[*p]) return 0; ++*p; return 1;
}
static int type(const char *s,size_t *p,unsigned depth,char *kind) {
 if(depth>32) return 0;
 while(s[*p] && strchr("rnNoORV",s[*p])) ++*p;
 char c=s[*p]; if(!c) return 0; *kind=c; ++*p;
 if(strchr("cislqCISLQfdDBv*#:?",c)) return 1;
 if(c=='@') { if(s[*p]=='?') ++*p; return quoted(s,p); }
 if(c=='^') { char ignored; return type(s,p,depth+1,&ignored); }
 if(c=='b') { if(!isdigit((unsigned char)s[*p])) return 0; while(isdigit((unsigned char)s[*p])) ++*p; return 1; }
 if(c=='[') {
  if(!isdigit((unsigned char)s[*p])) return 0;
  while(isdigit((unsigned char)s[*p])) ++*p;
  char ignored; if(!type(s,p,depth+1,&ignored) || s[*p]!=']') return 0; ++*p; return 1;
 }
 if(c=='{' || c=='(') {
  char end=c=='{'?'}':')';
  while(s[*p] && s[*p]!='=' && s[*p]!=end) ++*p;
  if(s[*p]==end) { ++*p; return 1; }
  if(s[*p]!='=') return 0; ++*p;
  while(s[*p] && s[*p]!=end) { char ignored; if(!quoted(s,p) || !type(s,p,depth+1,&ignored)) return 0; }
  if(s[*p]!=end) return 0; ++*p; return 1;
 }
 return 0;
}
int lx_signature(const char *s,LXType *out,size_t cap,size_t *count) {
 if(!s || !out || !count || strlen(s)>16384) return 0;
 size_t p=0,n=0;
 while(s[p]) {
  if(n==cap) return 0;
  size_t start=p; char kind;
  if(!type(s,&p,0,&kind)) return 0;
  out[n++]=(LXType){kind,start,p-start};
  if(s[p]=='+' || s[p]=='-') ++p;
  while(isdigit((unsigned char)s[p])) ++p;
 }
 *count=n; return n>=3 && out[1].kind=='@' && out[2].kind==':';
}
const char *lx_kind_name(char c) {
 switch(c) {
 case '@':return "object / block"; case '#':return "Class"; case ':':return "SEL";
 case '^':case '*':return "pointer";case 'B':return "BOOL";case 'f':return "float";
 case 'd':return "double";case 'D':return "long double";case 'v':return "void";
 case '[':return "array";case '{':return "struct";case '(':return "union";
 case 'b':return "bitfield";case '?':return "unknown";
 default:return "integer";
 }
}
