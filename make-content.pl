#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use 5.010000;
use autodie;

use Text::Xslate qw(mark_raw);
use Text::Markdown::Hoedown qw(markdown);
use HTML::TreeBuilder;
use HTML::TreeBuilder::XPath;
use HTML::Selector::XPath 'selector_to_xpath';
use HTML::Element;

my $src = slurp('template.html');
my $xslate = Text::Xslate->new();
my $inner = markdown(slurp('index.md'));
($inner, my $toc) = make_toc($inner);
my $html = $xslate->render_string(
    $src, {
        html => scalar(mark_raw($inner)),
        toc => scalar(mark_raw($toc)),
    }
);
spew('index.html', $html);

sub make_toc {
    my $html = shift;
    my $h = HTML::TreeBuilder::XPath->new();
    $h->parse($html);
    $h->eof;
    my @toc;
    my $i = 1;
    for ($h->findnodes(selector_to_xpath 'h1,h2,h3')) {
        my $title = $_->as_text;
        my $tag = $_->tag;
        my $level = $tag =~ s/^h//r;
        $_->push_content(do {
            my $e = HTML::Element->new('a', name => 'n' . $i, href => "#n$i", class => 'toc-anchor');
            $e->push_content(HTML::Element->new('~literal', text => '&dagger;'));
            $e;
        });
        push @toc, sprintf q{%s<a href="#n%d">%s</a>}, '&nbsp;'x$level, $i, $title;
        $i++;
    }
    my $ohtml = $h->as_HTML(q{&<>"'}, '  ');
    $ohtml =~ s!<body>!!;
    $ohtml =~ s!<html>!!;
    $ohtml =~ s!</html>!!;
    $ohtml =~ s!</body>!!;
    return ($ohtml, join("<br>", @toc));
}

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
