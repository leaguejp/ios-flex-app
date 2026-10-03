#ifndef LX_MACHO_H
#define LX_MACHO_H
#include <stddef.h>
#include <stdint.h>
typedef void (*LXEmit)(void *context,const char *key,const char *value);
/* No pointer dereferences into target processes; strictly file-relative bounds. */
int lx_macho(const uint8_t *data,size_t length,LXEmit emit,void *context,char *error,size_t error_size);
#endif
