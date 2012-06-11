package File::Symlink::Atomic;
use strict;
use warnings;
# ABSTRACT: an atomic drop-in replacement for CORE::symlink
# VERSION

use File::Temp;
use File::Spec;
use Exporter qw(import);
our @EXPORT = qw(symlink);

=head1 SYNOPSIS

    use File::Symlink::Atomic;   # imports replacement symlink
    symlink "target", "name1";   # easy peasy
    symlink "bullseye", "name1"; # now atomic

=head1 DESCRIPTION

Actually creating a symlink is not problematic, but making an existing one point
at a new target may not be atomic on your system. For example, on Linux, the
system does C<unlink> and then C<symlink>. In between, no symlink exists. If
something goes wrong, you're left with nothing.

In your shell, you probably want to do something like:

    mkdir old-target new target # Create your targets
    ln -s old-target link       # Create your initial symlink
    # ln -sf new-target link    # NOT atomic!
    ln -s new-target link-tmp && mv -Tf link-tmp link

Moving the symlink to the new name makes it atomic, because under the hood, the
C<mv> command does C<rename>, which is guaranteed to be atomic by
L<POSIX|http://pubs.opengroup.org/onlinepubs/9699919799/functions/rename.html>.

B<File::Symlink::Atomic> attempts to do the same thing in Perl what the command
shown above does for your shell.

=head1 FUNCTIONS

=head2 symlink OLDFILE,NEWFILE

Creates a new filename symbolically linked to the old filename.
Returns C<1> for success, C<0> otherwise. This drop-in replacement
for C<CORE::symlink> creates a symlink with a temporary name, then
renames it to the name you requested - this ensures that if a
symlink by the requested name already existed, then its target is
updated atomically.

=cut
    
sub symlink($$) {
    my $symlink_target = shift;
    my $symlink_name   = shift;

    my ($volume, $dirs, $file) = File::Spec->splitpath($symlink_name);
    my $template = File::Spec->catpath($volume, $dirs, ".$file.$$.XXXXXX");
    my $tmp_symlink_name;
    ATTEMPT:
    for (1..10) { # try 10 times
        $tmp_symlink_name = mktemp($template);
        symlink $symlink_target, $tmp_symlink_name and last ATTEMPT;
    }
    return 0 unless -l $tmp_symlink_name; # wtf?
    
    rename $tmp_symlink_name, $symlink_name or return 0; # should be atomic
    return 1;
}

1;

=head1 CAVEATS

This module is B<not> guaranteed to be portable. I have no idea what this will
do on any platform other than Linux. Feel free to run the test suite to find out!

=cut
