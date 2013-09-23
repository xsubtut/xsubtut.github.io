#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

XS(hello) {
    dVAR; dXSVARS; # おまじない

    # 出力する
    PerlIO_printf(PerlIO_stdout(), "Hello, world!\n");

    XSRETURN(0); # 返す値の数
}

