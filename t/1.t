#!/usr/bin/perl -w

use warnings;
use strict;

BEGIN
{
   use Test::More tests => 33;
   use_ok("SWF::NeedsRecompile", "check_files");
}

# HACK: remove the OS dependency so we can test just the file
# functionality without the user's classpath (if any) getting in the
# way
%SWF::NeedsRecompile::os_paths = ();

my $dir = "example";

# Set up some bogus file timestamps
my $new = time();
my $middle = $new - 60*60;
my $old = $middle - 60*60;

my $fla = "$dir/example.fla";
my $swf = "$dir/example.swf";

if (! -e $swf)
{
   local *OUT;
   open(OUT, "> $swf") or die;
   close(OUT);
}

# This is a list of "red herrings" which should not trigger the recompile
# Numbers 1 and 4 WILL trigger a recompile because they are in an
#   import exampleN.*;
# which considers all files in that directory to be suspect
my @herrings = (2,3,5,6,7);

# Build an easier-to-use version of the above
my %is_herring = map { ("$dir/lib/example$_/redherring.as" => 1) } @herrings;

my @files = (
   $fla,
   "$dir/lib/includetest.as",
   map({"$dir/lib/example$_/testclass.as"} 1..7),
   map({"$dir/lib/example$_/redherring.as"} 1..7),
);

# For each dependency listed in the @files array, try the check twice:
# once where the SWF is the newest file, and once where the specified
# file is the newest.  The first test should always indicate that
# there is no need for a recompile, while the latter should indicate
# that a recompile is needed unless the dependency is a red herring.

foreach my $file (@files)
{
   utime $old, $old, @files;
   utime $middle, $middle, $swf;
   is(scalar check_files($swf), 0, "check_files, old $file");

   utime $new, $new, $file;
   my $expect = $is_herring{$file} ? 0 : 1;
   is(scalar check_files($swf), $expect, "check_files, new $file");
}

END
{
   unlink $swf;
}
