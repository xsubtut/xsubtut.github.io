#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"


MODULE = Gimme		PACKAGE = Gimme		

void
gimme(...)
PPCODE:
{
    if (GIMME_V == G_ARRAY) {
        XPUSHs(sv_2mortal(newSViv(1)));
        XPUSHs(sv_2mortal(newSViv(2)));
        XPUSHs(sv_2mortal(newSViv(3)));
        XSRETURN(3);
    } else if (GIMME_V == G_VOID) {
        XSRETURN(0);
    } else if (GIMME_V == G_SCALAR) {
        XPUSHs(sv_2mortal(newSViv(5963)));
        XSRETURN(1);
    } else {
        abort();
    }
}
