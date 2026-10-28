#!/usr/bin/env bash
# CARO post-render HTML normalizer. Quarto's website templates emit markup the
# theme cannot fix from SCSS or includes; this rewrites every *.html under the
# rendered site in place, after `quarto render`:
#
#   bash _extensions/caro-quarto/caro-post-render.sh _site
#
# Idempotent: a second run leaves every file byte-identical. Portable to macOS
# (bash 3.2, BSD find) and Linux: all edits are perl. A page it cannot read the
# way it expects (two skip links, no single <body>) stops the run with an error
# instead of being skipped.
#
#   - navbar: drop role="menu" from the toggle button (a collapse is not a menu,
#     axe aria-allowed-role) and name the navbar landmark "Site" (beside the TOC,
#     axe landmark-unique).
#   - skip link: Quarto puts include-before-body inside <main>, after the navbar
#     and the TOC, so skip-link.html skipped nothing. Move it to the first child
#     of <body> and make <main id="quarto-document-content"> focusable (-1).
#   - validity: drop append-hash from <link> and role="link" from navbar
#     dropdown toggles (Nu HTML checker error and redundant role).
#   - fonts: fonts/fonts.css becomes the first stylesheet in <head>, after
#     preloads of the core faces every page draws above the fold.
#   - scripts: defer the five classic Quarto head scripts.
set -euo pipefail

DIR="${1:-}"
if [[ -z "${DIR}" || ! -d "${DIR}" ]]; then
  echo "usage: caro-post-render.sh <rendered-site-dir>" >&2
  exit 2
fi

# shellcheck disable=SC2016 # perl source, not shell
PERL='
use strict; use warnings;
my $status = 0;
# Core (Latin-1) faces every fleet page draws in its first viewport, measured
# per page type at 1280 and 412 px (main-site pages and research/visual pieces).
my @PRELOAD = qw(Literata-core Newsreader-core FiraSans-Regular-core);
FILE: for my $file (@ARGV) {
  open(my $in, "<:raw", $file) or die "caro-post-render: $file: $!\n";
  my $html = do { local $/; <$in> }; close $in;
  my $orig = $html;
  my $fail = sub { print STDERR "caro-post-render: $file: $_[0]\n"; $status = 1; };

  # navbar (the same substitution sites ran as scripts/strip-navbar-menu-role.sh)
  $html =~ s/(<button class="navbar-toggler[^>]*?) role="menu"/$1/g;
  $html =~ s/(<nav class="navbar[^"]*")(?![^>]*aria-label)/$1 aria-label="Site"/g;

  # append-hash is not an HTML attribute (Nu validator error; no script reads
  # it), and role="link" on an <a href> dropdown toggle repeats its implicit role
  $html =~ s/(<link\b[^>]*?) append-hash="[^"]*"/$1/g;
  $html =~ s{(<a\b[^>]*>)}{ my $t = $1; $t =~ s/ role="link"// if $t =~ /\bclass="[^"]*\bdropdown-toggle\b/; $t }ge;

  # skip link: first child of <body>; its target takes programmatic focus
  my @skip = ($html =~ /(<a\b[^>]*\bclass="skip-link"[^>]*>.*?<\/a>)/gs);
  if (@skip > 1) { $fail->(scalar(@skip) . " skip links"); next FILE; }
  if (@skip == 1) {
    my $bodies = () = $html =~ /<body\b[^>]*>/g;
    if ($bodies != 1) { $fail->("skip link but $bodies <body> tags"); next FILE; }
    my $link = $skip[0];
    $html =~ s/[ \t]*\Q$link\E\n?//;
    $html =~ s/(<body\b[^>]*>)\n?/$1\n$link\n/;
  }
  $html =~ s{(<main\b[^>]*\bid="quarto-document-content"[^>]*)>}{
    my $t = $1; $t =~ /\btabindex=/ ? "$t>" : "$t tabindex=\"-1\">" }e;

  # fonts (Quarto pages only): fonts.css becomes the first stylesheet, preceded
  # by preloads of the core faces, so the woff2 requests start with the HTML
  # instead of after every Quarto stylesheet. Preload hrefs reuse the directory
  # of the fonts.css href on the page, so depth (../) and root-absolute 404
  # pages stay right.
  if ($html =~ /<meta name="generator" content="quarto-/) {
    my ($head, $rest) = split /(?=<\/head>)/, $html, 2;
    my @css = ($head =~ /(<link rel="stylesheet" href="([^"]*)fonts\/fonts\.css">)/g);
    if (@css > 2) { $fail->("more than one fonts.css link"); next FILE; }
    if (@css && defined $rest) {
      my ($tag, $dir) = @css;
      $head =~ s/<link rel="preload" href="\Q${dir}\Efonts\/[^"]*" as="font" type="font\/woff2" crossorigin>\n//g;
      $head =~ s/\Q$tag\E\n?//;
      my $block = join "", map { "<link rel=\"preload\" href=\"${dir}fonts/$_.woff2\" as=\"font\" type=\"font/woff2\" crossorigin>\n" } @PRELOAD;
      unless ($head =~ s/(?=<script\b[^>]*\bsrc=|<link\b[^>]*\brel="stylesheet")/$block$tag\n/) {
        $head .= "$block$tag\n";
      }
      $html = $head . $rest;
    }
  }

  # The five classic head scripts block parsing. Every use of their
  # globals (Headroom, bootstrap, tippy) runs from a DOMContentLoaded handler or
  # a click, and deferred scripts run, in order, before DOMContentLoaded.
  $html =~ s{(<script src="[^"]*/(?:quarto-nav/quarto-nav\.js|quarto-nav/headroom\.min\.js|quarto-html/popper\.min\.js|quarto-html/tippy\.umd\.min\.js|bootstrap/bootstrap\.min\.js)")></script>}{$1 defer></script>}g;

  next FILE if $html eq $orig;
  open(my $out, ">:raw", $file) or die "caro-post-render: $file: $!\n";
  print $out $html; close $out or die "caro-post-render: $file: $!\n";
}
exit $status;
'

find "${DIR}" -name '*.html' -type f -exec perl -e "${PERL}" {} +
