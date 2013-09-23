#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use 5.010000;
use autodie;

use Text::Xslate qw(mark_raw);
use Text::Markdown::Discount qw(markdown);

my $src = slurp('template.html');
my $xslate = Text::Xslate->new();
my $html = $xslate->render_string(
    $src, {
        html => scalar(mark_raw markdown(slurp('index.md'))),
    }
);
spew('index.html', $html);

sub spew {
    my $fname = shift;
    open my $fh, '>', $fname
        or Carp::croak("Can't open '$fname' for writing: '$!'");
    print {$fh} $_[0];
}

sub slurp {
    my $fname = shift;
    open my $fh, '<', $fname
        or Carp::croak("Can't open '$fname' for reading: '$!'");
    scalar(do { local $/; <$fh> })
}
