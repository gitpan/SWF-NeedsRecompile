#!/usr/bin/perl -w

use warnings;
use strict;

BEGIN
{
   use Test::More tests => 40;
   use_ok("SWF::NeedsRecompile", "check_files");
}

#$SWF::NeedsRecompile::verbose = 1;

my @tempfiles;
END { unlink $_ for (@tempfiles); }

# HACK: remove the OS dependency so we can test just the file
# functionality without the user's classpath (if any) getting in the
# way
%SWF::NeedsRecompile::os_paths = ();

### First some basic tests

is_deeply([check_files("foo.txt")], [], "invalid filename");
is_deeply([check_files("foo.swf")], ["foo.swf"], "non-existent swf");

unlink "example/simple.swf";
is_deeply([check_files("example/simple.fla")], ["example/simple.fla"], "simple fla");
_touch("example/simple.swf");
push @tempfiles, "example/simple.swf";
is_deeply([check_files("example/simple.fla")], [], "simple fla");

unlink "example/broken.swf";
is_deeply([check_files("example/broken.fla")], ["example/broken.fla"], "broken fla");
_touch("example/broken.swf");
push @tempfiles, "example/broken.swf";
is_deeply([check_files("example/broken.fla")], ["example/broken.fla"], "broken fla");

_touch("example/missing.swf");
push @tempfiles, "example/missing.swf";
is_deeply([check_files("example/missing.fla")], ["example/missing.fla"], "missing fla");

### Now the more sophisticated tests

# Set up some bogus file timestamps
my $new = time();
my $middle = $new - 60*60;
my $old = $middle - 60*60;

my $fla = "example/example.fla";
my $swf = "example/example.swf";

_touch($swf);
push @tempfiles, $swf;

# This is a list of "red herrings" which should not trigger the recompile
# Numbers 1 and 4 WILL trigger a recompile because they are in an
#   import exampleN.*;
# which considers all files in that directory to be suspect
my @herrings = (2,3,5,6,7);

# Build an easier-to-use version of the above
my %is_herring = map { ("example/lib/example$_/redherring.as" => 1) } @herrings;

my @files = (
   $fla,
   "example/lib/includetest.as",
   map({"example/lib/example$_/testclass.as"} 1..7),
   map({"example/lib/example$_/redherring.as"} 1..7),
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

sub _touch
{
   my $name = shift;
   local *OUT;
   open(OUT, "> $name") or die;
   close(OUT);
}
