package OneEncoding;

use 5.010001;
use strict;
use warnings;
use Filter::Util::Call;

our $VERSION    = '0.02';
our $LINENO     = 0;
our $ENCODING   = 1;

sub import
{
    my $class = shift;
    my $encoding = shift;
    $encoding or die "Usage: use OneEncodingE 'ENCODING';";
    filter_add( bless [ 0, $encoding ] );
}

sub filter
{
    my $self = $_[0];

    my $status = filter_read();
    if ( $status > 0 )
    {
        s/ -e \s+ ( \$\w+ | '[^']*' | "[^"]*" ) /sub{ stat($1); -e _ }->()/gx;  # '
    }

    if ( ++$self->[$LINENO] == 1 )
    {
        my $encoding = $self->[$ENCODING];
        my $lines_to_add;
        if ( $] =~ /^5.016/ )
        {
            $lines_to_add = <<ADD;
use encoding '$encoding';
use open ':std';
use open ':encoding($encoding)';
use OneEncoding::CORE '$encoding';
ADD
        }
        else
        {
            $lines_to_add = <<ADD;
use encoding '$encoding';
use open ':encoding($encoding)';
use open ':std';
use OneEncoding::CORE '$encoding';
ADD
        }
        s/^/$lines_to_add/;
    }

    $status;
}

1;
__END__

=head1 NAME

OneEncoding - Perl extension for blah blah blah

=head1 SYNOPSIS

  use OneEncoding::Filter;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for OneEncoding::CORE, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

A. U. Thor, E<lt>a.u.thor@a.galaxy.far.far.awayE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by A. U. Thor

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.16.3 or,
at your option, any later version of Perl 5 you may have available.


=cut
