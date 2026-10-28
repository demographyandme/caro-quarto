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
FILE: for my $file (@ARGV) {
  open(my $in, "<:raw", $file) or die "caro-post-render: $file: $!\n";
  my $html = do { local $/; <$in> }; close $in;
  my $orig = $html;
  my $fail = sub { print STDERR "caro-post-render: $file: $_[0]\n"; $status = 1; };

  # navbar (the same substitution sites ran as scripts/strip-navbar-menu-role.sh)
  $html =~ s/(<button class="navbar-toggler[^>]*?) role="menu"/$1/g;
  $html =~ s/(<nav class="navbar[^"]*")(?![^>]*aria-label)/$1 aria-label="Site"/g;

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

  next FILE if $html eq $orig;
  open(my $out, ">:raw", $file) or die "caro-post-render: $file: $!\n";
  print $out $html; close $out or die "caro-post-render: $file: $!\n";
}
exit $status;
'

find "${DIR}" -name '*.html' -type f -exec perl -e "${PERL}" {} +
