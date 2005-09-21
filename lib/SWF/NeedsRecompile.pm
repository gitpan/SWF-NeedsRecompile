package SWF::NeedsRecompile;

use warnings;
use strict;
use File::Spec;
use File::Basename;
use Carp;
use Exporter;

our $VERSION = "1.01";
our @ISA = qw(Exporter);
our @EXPORT;
our @EXPORT_OK = qw(check_files as_classpath flash_prefs_path flash_config_path);
our $verbose = 0;

our %os_paths = (
   darwin => {
      pref => ["$ENV{HOME}/Library/Preferences/Flash 7 Preferences"],
      conf => ["$ENV{HOME}/Library/Application Support/Macromedia/Flash MX 2004/en/Configuration"],
   },
   # TODO: add more entries for "MSWin32", etc
);

=head1 NAME 

SWF::NeedsRecompile - Tests if any SWF or FLA file dependencies have changed

=head1 LICENSE

Copyright Clotho Advanced Media Inc.

This software is released by Clotho Advanced Media, Inc. under the same
terms as Perl itself.  That means that it is dual-licensed under the
Artistic license and the GPL, and that you can redistribute it and/or
modify it under the terms of either or both of those licenses.  See
the "LICENSE" file, or visit http://www.clotho.com/code/Perl

The definitive source of Clotho Advanced Media software is
http://www.clotho.com/code/

All of our software is also available under commercial license.  If
the Artisic license or the GPL does not meet the needs of your
project, please contact us at info@clotho.com or visit the above URL.

We release open source software to help the world.  We hope that you
will enjoy this software, and we also hope and that you will hire us.
As authors of this software, we are best able to help you integrate it
into your project and to assist you with any problems.

=head1 SYNOPSIS

    use SWF::NeedsRecompile qw(check_files);
    foreach my $file (check_files(<*.swf>)) {
       print "SWF needs recompilation: $file\n";
    }

=head1 DESCRIPTION

This module parses .fla and .as files and determines dependencies
recursively, via import and #include statements.  It then compares the
timestamps of all of the dependencies against the timestamp of the
.swf file.  If any dependency is newer than the .swf, that file needs
to be recompiled.

=head1 LIMITATIONS

This module only works in its entirety on Mac OS X, and for Flash MX
2004.  Help wanted: extend it to Windows (add appropriate search paths
at the top of the .pm file) and extend it to the Flash 8 author when
that is available.

This module only reports whether or not the .swf is up to date.  It
would be useful to know whether it is out of date because of the .fla
file or any .as files.  In the latter case, the open source MTASC
(L<http://www.mtasc.org/>) application could perform the
recompilation.

This module likely only works with ASCII filenames.  The heuristic
used to parse the binary .fla files discards the upper Unicode byte of
any filenames.

If there are C<import> statements with wildcards in any .as files,
then all files in the specified directory are considered dependencies,
even if only a subset are actually used.

Direct access to class methods are not detected.  So, if you
Actionscript does something like C<com.example.Foo.doSomething()> then
com/example/Foo.as is not detected as a dependency.  The workaround is
to add an import; in this example it would be
C<import com.example.Foo;>

=head1 FUNCTIONS

=over

=cut

sub _log
{
   print @_ if ($verbose);
}

=item check_files FILE, FILE, ...

Examine a list of .swf and/or .fla files and return the filenames of
the ones that need to be recompiled.

Performance note: Information is cached across files, so it's faster
to call this function once with a bunch of files than a bunch of times
with one file each invocation.

=cut

sub check_files
{
   my @files = @_;

   my @needsRecompile;

   # The depends hash is a cache of the #include and import lines in each file
   my %depends = ();

   foreach my $file (@files)
   {
      (my $base = $file) =~ s/\.(?:swf|fla)$//;
      if ($base eq $file)
      {
         _log("$file is not a .swf or a .fla file\n");
         next;
      }
      my $swf = "$base.swf";
      my $fla = "$base.fla";

      # Do the simple case first
      if (! -e $swf)
      {
         push @needsRecompile, $file;
         next;
      }

      # Look for FLA-specific Classpaths
      my @paths = _get_fla_classpaths($fla);

      # Check all SWF dependencies, recursively
      my @check = ($fla);
      my %checked = ();
      my $up_to_date = 1;
      while (@check > 0)
      {
         my $checkfile = pop @check;
         next if ($checked{$checkfile});

         if (! -f $checkfile)
         {
            _log("Failed to locate file needed to compile $swf:  $checkfile\n");
            $up_to_date = 0;
            last;
         }

         _log("check $checkfile\n");
         $up_to_date = _up_to_date($checkfile, $swf);
         $checked{$checkfile} = 1;
         if (!$up_to_date)
         {
            _log("Failed up to date check for $checkfile vs. $swf\n");
            last;
         }

         if (! -r $checkfile)
         {
            _log("Unreadable file $checkfile\n");
            last;
         }

         if (!$depends{$checkfile})
         {
            _log("do deps for $checkfile\n");
            $depends{$checkfile} = [];
            local *FILE;
            local $/; # Slurp files whole
            open(FILE, $checkfile) || croak "This shouldn't happen since the file is supposed to be readable";
            my $content = <FILE>;
            close FILE;

            my %imported_files;
            my %seen;
            
            # check for include and import statements and instantiations via "new"
            my @deps = (
               _get_includes($checkfile, \$content, \%seen),
               _get_imports($checkfile, \$content, \@paths, \%imported_files, \%seen),
               _get_instantiations($checkfile, \$content, \@paths, \%imported_files, \%seen),
            );
            my @problems = map {@$_} grep {ref $_} @deps;
            if (@problems > 0)
            {
               _log("Failed to locate dependencies in $checkfile: @problems\n");
               $up_to_date = 0;
               last;
            }
            $depends{$checkfile} = \@deps;
         }
         push @check, @{$depends{$checkfile}};
      }

      unless ($up_to_date)
      {
         push @needsRecompile, $file;
      }
   }
   return @needsRecompile;
}

sub _get_fla_classpaths
{
   my $fla = shift;

   local *FLA;
   local $/; # Slurp files whole
   my @paths;
   if (open(FLA, $fla))
   {
      my $content = <FLA>;
      close FLA;
      # Limitation: the path must be purely ASCII or this doesn't work
      @paths = $content =~ /V\0e\0c\0t\0o\0r\0:\0:\0P\0a\0c\0k\0a\0g\0e\0 \0P\0a\0t\0h\0s\0....((?:[^\0]\0)*)/g;
      if (@paths > 0)
      {
         my $path = $paths[-1];
         $path =~ s/\0//g;
         @paths = split /;/, $path;
         require File::Spec;
         for (@paths)
         {
            if (!File::Spec->file_name_is_absolute($_))
            {
               my $dir = [File::Spec->splitpath($fla)]->[1];
               if ($dir)
               {
                  $_ = File::Spec->rel2abs($_, $dir);
               }
            }
         }
      }
      _log("FLA Paths: @paths\n");
   }
   return @paths;
}

sub _get_includes
{
   my $checkfile = shift;
   my $content_ref = shift;
   my $seen_ref = shift;

   my @deps;

   # Check both ascii and ascii-unicode, supporting Flash MX and 2004 .fla files
   # This will fail for non-ascii filenames
   my @matches = $$content_ref =~ /\#\0?i\0?n\0?c\0?l\0?u\0?d\0?e\0?(?:\s\0?)+\"\0?([^\"\r\n]+?)\"/gs;
   foreach my $inc (@matches)
   {
      next if ($seen_ref->{$inc}++); # speedup
      # This is a hack.  Strip real Unicode down to ASCII
      $inc =~ s/\0//g;
      if ($inc)
      {
         my $file = $inc;
         if (! -f $file)
         {
            if (! File::Spec->file_name_is_absolute($file))
            {
               my $dir = [File::Spec->splitpath($checkfile)]->[1];
               if ($dir)
               {
                  $file = File::Spec->rel2abs($file, $dir);
               }
            }
            return [$inc] if (! -f $file);
         }
         push @deps, $file;
         _log("#include $inc from $checkfile\n");
      }
   }
   return @deps;
}

sub _get_imports
{
   my $checkfile = shift;
   my $content_ref = shift;
   my $fla_path_ref = shift;
   my $imported_file_ref = shift;
   my $seen_ref = shift;

   my @deps;
   my @matches = $$content_ref =~ /i\0?m\0?p\0?o\0?r\0?t\0?(?:\s\0?)+((?:[^\;\0\s]\0?)+);/gs;
   foreach my $imp (@matches)
   {
      next if ($seen_ref->{$imp}++); # speedup
      # This is a hack.  Strip real Unicode down to ASCII
      $imp =~ s/\0//g;
      _log("import $imp from $checkfile\n");
      my $found = 0;
      foreach my $dir (@$fla_path_ref, as_classpath())
      {
         my $f = File::Spec->catdir(File::Spec->splitdir($dir), split(/\./, $imp));
         if ($f =~ /\*$/)
         {
            my @d = File::Spec->splitdir($f);
            pop @d;
            $f = File::Spec->catdir(@d);
            local *DIR;
            if (opendir(DIR, $f))
            {
               my @as = grep /\.as$/, readdir(DIR);
               closedir DIR;
               
               $imported_file_ref->{$_} = 1 for @as;
               @as = map {File::Spec->catfile($f, $_)} @as;
               
               for (@as)
               {
                  _log("  import $_ from $checkfile\n");
               }
               push @deps, @as;
            }
            $found = 1;
         }
         else
         {
            $f .= ".as";
            if (-f $f)
            {
               my @p = split /\./, $imp;
               $imported_file_ref->{$p[-1].".as"} = 1;
               _log("  import $f from $checkfile\n");
               push @deps, $f;
               $found = 1;
               last;
            }
         }
      }
      return [$imp] if (!$found);
   }
   return @deps;
}

sub _get_instantiations
{
   my $checkfile = shift;
   my $content_ref = shift;
   my $fla_path_ref = shift;
   my $imported_file_ref = shift;
   my $seen_ref = shift;

   my @deps;
   my @matches = $$content_ref =~ /n\0?e\0?w\0?(?:\s\0?)+((?:[^\(;\s\0]\0?)+)\(/gs;
   foreach my $imp (@matches)
   {
      next if ($seen_ref->{$imp}++); # speedup
      # This is a hack.  Strip real Unicode down to ASCII
      $imp =~ s/\0//g;
      _log("instance $imp from $checkfile\n");
      next if ($imported_file_ref->{$imp.".as"});
      my $found = 0;
      foreach my $dir (@$fla_path_ref, as_classpath())
      {
         my $f = File::Spec->catdir(File::Spec->splitdir($dir), split(/\./, $imp));
         $f .= ".as";
         if (-f $f)
         {
            _log("  instance $f from $checkfile\n");
            push @deps, $f;
            $found = 1;
            last;
         }
      }
      return [$imp] if (!$found);
   }
   return @deps;
}

=item as_classpath

Returns a list of Classpath directories specified globally in Flash.

=cut

my $cached_as_classpath;
sub as_classpath
{
   if (!$cached_as_classpath)
   {
      my $prefs_file = flash_prefs_path();
      if (!$prefs_file || ! -f $prefs_file)
      {
         #_log("Failed to locate the Flash prefs file\n");
         return (".");
      }

      my $conf_dir = flash_config_path();
      local *IN;
      open(IN, $prefs_file) || croak "Failed to open the Flash prefs file";
      while (<IN>)
      {
         if (/<Package_Paths>(.*?)<\/Package_Paths>/)
         {
            my $cp = $1;
            my @dirs = split /;/, $cp;
            for (@dirs)
            {
               if (!$conf_dir)
               {
                  _log("Failed to identify the UserConfig dir for '$_'\n");
               }
               else
               {
                  s/\$\(UserConfig\)/$conf_dir/;
               }
            }
            $cached_as_classpath = \@dirs;
            _log("Classpath: @{$cached_as_classpath}\n");
            last;
         }
      }
      close IN;
   }
   return @$cached_as_classpath;
}

=item flash_prefs_path

Returns the filename of the Flash preferences XML file.

=cut

sub flash_prefs_path
{
   return _get_path("pref");
}

=item flash_config_path

Returns the path where Flash stores all of its class prototypes.

=cut

sub flash_config_path
{
   return _get_path("conf");
}

# Internal helper for the above two functions
sub _get_path
{
   my $type = shift;

   my $os = $os_paths{$^O};
   if (!$os)
   {
      return undef;
      #croak "Operating system $^O is not currently supported.  We support:\n   ".
      #    join(" ", sort keys %os_paths)."\n";
   }
   my $list = $os->{$type};
   my @match = grep { -e $_ } @$list;
   if (@match == 0)
   {
      return undef;
      #croak join("\n  ", "Failed to find any of the following:", @$list)."\n";
   }
   return $match[0];
}

# A simplified version of Module::Build::Base::up_to_date
sub _up_to_date
{
   my $src = shift;
   my $dest = shift;

   return 0 if (! -e $dest);
   return 0 if (-M $dest > -M $src);
   return 1;
}

1;
__END__

=back

=head1 SEE ALSO

L<Module::Build::Flash> uses this module.

=head1 AUTHOR

Clotho Advanced Media Inc., I<cpan@clotho.com>

Primary developer: Chris Dolan
