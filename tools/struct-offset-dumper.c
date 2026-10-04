/*
 * struct-offset-dumper.c
 *
 * Get exact offsetof()/sizeof() values for a Postgres server-internal
 * struct by compiling against the real installed server headers, instead
 * of inferring byte layout from a hex dump. Hand-reconstructing a binary
 * format from observed bytes is error-prone and slow to iterate on; this
 * gets ground truth in one compile.
 *
 * Usage:
 *   1. Install the matching postgresql-server-dev package for your
 *      target's major version.
 *   2. Edit the #include and the struct definition / offsetof() calls
 *      below to match whatever struct you're investigating (copy the
 *      struct definition verbatim from the extension's own header, or
 *      from the relevant Postgres core header).
 *   3. Build and run:
 *
 *        gcc -I$(pg_config --includedir-server) struct-offset-dumper.c \
 *            -o struct-offset-dumper
 *        ./struct-offset-dumper
 *
 * Note: postgres.h redefines printf to an internal symbol (pg_printf)
 * that isn't available outside a full backend build. #undef it after
 * including the server headers to get ordinary libc printf back, or the
 * link step will fail with "undefined reference to pg_printf".
 */

#include "postgres.h"
/* #include whatever server header declares the struct you care about,
 * e.g. "storage/buf_internals.h" for BufferTag-style structs. */

#undef printf
#include <stdio.h>
#include <stddef.h>

/*
 * Example target struct -- replace with the real definition you're
 * verifying. Keep any flexible-array-member fields intact; offsetof()
 * on the array member itself gives you the fixed-header size.
 */
typedef struct ExampleHeader
{
    int32   vl_len_;      /* varlena header, if this is a bytea-backed type */
    uint32  magic;
    uint32  count;
    uint16  flags;
    /* flexible array member / variable-length payload follows */
} ExampleHeader;

int
main(void)
{
    printf("sizeof(ExampleHeader) = %zu\n", sizeof(ExampleHeader));
    printf("offsetof(ExampleHeader, magic) = %zu\n",
           offsetof(ExampleHeader, magic));
    printf("offsetof(ExampleHeader, count) = %zu\n",
           offsetof(ExampleHeader, count));
    printf("offsetof(ExampleHeader, flags) = %zu\n",
           offsetof(ExampleHeader, flags));

    /* Repeat this pattern for every struct and field relevant to the
     * wire/serialized format you're reconstructing. Cross-check every
     * value against a real, known-valid sample captured from a live
     * call before using it to build a crafted payload. */

    return 0;
}
