#ifndef LX_ENCODING_H
#define LX_ENCODING_H
#include <stddef.h>
typedef struct { char kind; size_t start, length; } LXType;
/* Bounded parser, including nested aggregates. Offsets are skipped by signature parser. */
int lx_signature(const char *text, LXType *types, size_t capacity, size_t *count);
const char *lx_kind_name(char kind);
#endif
