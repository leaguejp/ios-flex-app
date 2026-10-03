#ifndef LX_MACHO_H
#define LX_MACHO_H
#include <stddef.h>
#include <stdint.h>
typedef void (*LXEmit)(void *context,const char *key,const char *value);
/* No pointer dereferences into target processes; strictly file-relative bounds. */
int lx_macho(const uint8_t *data,size_t length,LXEmit emit,void *context,char *error,size_t error_size);
/* One class event (selector == NULL), followed by its instance/metaclass methods.
 * Strings are borrowed, bounded UTF-8 candidates; caller validates UTF-8.
 * Only ordinary little-endian arm64 files, classic pointers and chained 64/64_OFFSET.
 */
typedef void (*LXObjCEmit)(void *,const char *class_name,int class_method,const char *selector,const char *encoding);
int lx_macho_objc(const uint8_t *,size_t,LXObjCEmit,void *,char *,size_t);
#endif
