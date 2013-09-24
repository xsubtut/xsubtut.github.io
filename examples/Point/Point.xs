#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

typedef struct {
    int x;
    int y;
} Point;

Point* point_new(int x, int y) {
    Point *p = malloc(sizeof(Point));
    p->x = x;
    p->y = y;
    return p;
}

void point_free(Point* point) {
    free(point);
}

#define XS_STATE(type, x)     (INT2PTR(type, SvROK(x) ? SvIV(SvRV(x)) : SvIV(x)))

#define XS_STRUCT2OBJ(sv, class, obj, is_root) \
    sv = newSViv(PTR2IV(obj));  \
    sv = newRV_noinc(sv); \
    sv_bless(sv, gv_stashpv(class, 1)); \
    SvREADONLY_on(sv);

MODULE = Point		PACKAGE = Point		

void
new(...)
PPCODE:
{
    if (items != 3) {
        croak("Bad argument count: %d", items);
    }

    const char *klass = SvPV_nolen(ST(0));
    IV x = SvIV(ST(1));
    IV y = SvIV(ST(2));

    Point *point = Point_new(x, y);
    SV *sv;
    XS_STRUCT2OBJ(sv, klass, point);
    XPUSHs(sv_2mortal(sv));
    XSRETURN(1);
}

void
x(...)
PPCODE:
{
    if (items != 1) {
        croak("Bad argument count: %d", items);
    }

    Point* point = XS_STATE(Point*, ST(0));
    XPUSHs(sv_2mortal(newSViv(point->x)));
    XSRETURN(1);
}

void
y(...)
PPCODE:
{
    if (items != 1) {
        croak("Bad argument count: %d", items);
    }

    Point* point = XS_STATE(Point*, ST(0));
    XPUSHs(sv_2mortal(newSViv(point->y)));
    XSRETURN(1);
}

void
DESTROY(...)
PPCODE:
{
    if (items != 1) {
        croak("Bad argument count: %d", items);
    }

    Point* point = XS_STATE(Point*, ST(0));
    point_free(point);
    XSRETURN(0);
}
