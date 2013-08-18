package OneEncoding::CORE;

use 5.010001;
use strict;
use warnings;
use Encode;

our $VERSION = '0.02';
my $encoding;
my $decoding_argv_done;
my $override_done;

sub import
{
    my $class = shift;
    $encoding = shift;
    $encoding or die "Usage: use OneEncoding::CORE 'ENCODING';";
    $decoding_argv_done ||= decode_argv();
    $override_done ||= override_by_encoding_funcs();
}

sub decode_argv
{
    @ARGV = map{ decode( $encoding, $_ ) } @ARGV;
    1;
}

sub override_by_encoding_funcs
{
    my $caller = caller(1);

    no strict 'refs';

    *{"${caller}::open"} = sub
    {
        my $file = $_[1];
        $file =~ s/^(\s*[<>]\s*)//;
        my $io = $1 || '<';
        my $io_encoding = "$io:encoding($encoding)";

        if ( !defined( $_[0] ) )
        {
            # for the newer style: open( my $csv, ... );
            CORE::open( $_[0], $io_encoding, encode( $encoding, $file ) );
        }
        else
        {
            # for the older style: open( CSV, ... );
            my $sym;
            CORE::open( $sym, $io_encoding, encode( $encoding, $file ) );
            *{"${caller}::$_[0]"} = $sym;
        }
    };

    *{"${caller}::stat"} = sub
    {
        my $file = encode( $encoding, $_[0] );
        CORE::stat( $file );
    };

    *{"${caller}::rename"} = sub
    {
        my @file = map{ encode( $encoding, $_ ) } @_;
        CORE::rename( $file[0], $file[1] );
    };

    *{"${caller}::unlink"} = sub
    {
        my $file = encode( $encoding, $_[0] );
        CORE::unlink( $file );
    };

    *{"${caller}::system"} = sub
    {
        my $cmd = encode( $encoding, $_[0] );
        CORE::system( $cmd );
    };

    *{"${caller}::glob"} = sub
    {
        my $expr = encode( $encoding, $_[0] );
        map{ decode( $encoding, $_ ) } CORE::glob( $expr );
    };
    1;
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

OneEncoding::CORE - Perl extension for blah blah blah

=head1 SYNOPSIS

  use OneEncoding::CORE;
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
