#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

MODULE = Hello		PACKAGE = Hello

void
hello()
PPCODE:
{
    PerlIO_printf(PerlIO_stdout(), "Hello, world!\n");
    XSRETURN(0);
}
