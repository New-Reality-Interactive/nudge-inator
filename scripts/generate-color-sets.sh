#!/usr/bin/env bash
# Writes the app's color sets (App/Resources/Assets.xcassets) from DESIGN.md's frontmatter `colors`.
# Run it after changing a custom color in docs/design/DESIGN.md, then run scripts/test.sh:
# ColorSetTests pins every value, so update its table too. scripts/test.sh also fails if the
# catalog no longer matches DESIGN.md (it passes an output directory, $1, to compare).
#
# Only the custom colors get sets (DESIGN.md › Mapping to code); system semantic colors such as
# grouped-background are used by name. Each set has four appearances, from the key's variants:
#   Any = x, Dark = x-dark, High Contrast = x-ic, Dark High Contrast = x-dark-ic.
# A missing variant falls back: dark to x, high contrast to x, and dark high contrast to x-dark if
# the key has one, else x-ic, else x. So badge (no dark) keeps badge-ic in dark high contrast, and
# a tile (one value) is the same everywhere.
set -euo pipefail
# An output path is taken from where the script was run, before moving to the repo root.
out="${1:-App/Resources/Assets.xcassets}"
case "$out" in /*) ;; *) out="$PWD/$out" ;; esac
cd "$(dirname "$0")/.."
if [ -z "${1:-}" ]; then out="$PWD/App/Resources/Assets.xcassets"; fi

perl -e '
  use strict; use warnings;
  my ($design, $catalog) = @ARGV;
  # Frontmatter key => color set name. AccentColor is the name Xcode applies as the app tint.
  my @sets = (
    [accent => "AccentColor"], ["on-accent" => "OnAccent"], [negative => "Negative"],
    [warning => "Warning"], [positive => "Positive"], [neutral => "Neutral"], [badge => "Badge"],
    ["tile-red" => "TileRed"], ["tile-orange" => "TileOrange"], ["tile-gray" => "TileGray"],
    ["tile-blue" => "TileBlue"], ["tile-green" => "TileGreen"],
  );

  open(my $fh, "<", $design) or die "$design: $!\n";
  my (%hex, $inColors, $fences);
  while (<$fh>) {
    if (/^---\s*$/) { last if ++$fences == 2; next }
    if (/^colors:\s*$/) { $inColors = 1; next }
    $inColors = 0 if /^\S/;
    $hex{$1} = uc $2 if $inColors && /^\s+([a-z0-9-]+):\s*\x27#([0-9A-Fa-f]{6})\x27/;
  }
  close $fh;

  sub components {
    my ($h) = @_;
    my ($r, $g, $b) = map { "0x" . substr($h, $_ * 2, 2) } 0 .. 2;
    return qq({ "color-space" : "srgb", "components" : { "alpha" : "1.000", "blue" : "$b", "green" : "$g", "red" : "$r" } });
  }
  sub entry {
    my ($h, @appearances) = @_;
    my $looks = @appearances ? qq("appearances" : [ ) . join(", ", @appearances) . qq( ], ) : "";
    return qq(    { ${looks}"color" : ) . components($h) . qq(, "idiom" : "universal" });
  }
  my $dark = q({ "appearance" : "luminosity", "value" : "dark" });
  my $high = q({ "appearance" : "contrast", "value" : "high" });
  my $info = q("info" : { "author" : "xcode", "version" : 1 });

  mkdir $catalog;
  open(my $root, ">", "$catalog/Contents.json") or die "$catalog: $!\n";
  print $root "{\n  $info\n}\n";
  close $root;

  for my $set (@sets) {
    my ($key, $name) = @$set;
    my $any = $hex{$key} // die "DESIGN.md has no colors.$key\n";
    my $darkHex = $hex{"$key-dark"} // $any;
    my $icHex = $hex{"$key-ic"} // $any;
    my $darkIcHex = $hex{"$key-dark-ic"} // ($hex{"$key-dark"} // $icHex);
    my $dir = "$catalog/$name.colorset";
    mkdir $dir;
    open(my $out, ">", "$dir/Contents.json") or die "$dir: $!\n";
    print $out "{\n  \"colors\" : [\n", join(",\n",
      entry($any), entry($darkHex, $dark), entry($icHex, $high), entry($darkIcHex, $dark, $high)),
      "\n  ],\n  $info\n}\n";
    close $out;
  }
' docs/design/DESIGN.md "$out"

echo "Wrote $out"
