package OneEncoding::CORE;

use 5.010001;
use strict;
use warnings;
use Encode;

our $VERSION = '0.02';
my $encoding;

sub import
{
    my $class = shift;
    $encoding = shift;
    $encoding or die "Usage: use OneEncoding::CORE 'ENCODING';";
    my $caller = caller;

    # print "DEBUG: OneEncoding::CORE import $caller\n";

    decode_argv() if $caller eq 'main';
    override_by_encoding_funcs();
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

    *{"${caller}::open"} = sub (*;$@)
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

    *{"${caller}::stat"} = sub (;*)
    {
        my $file = encode( $encoding, $_[0] );
        CORE::stat( $file );
    };

    *{"${caller}::rename"} = sub ($$)
    {
        my @file = map{ encode( $encoding, $_ ) } @_;
        CORE::rename( $file[0], $file[1] );
    };

    *{"${caller}::unlink"} = sub (@)
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

=head1 NAME

OneEncoding::CORE - override CORE functions

=head1 SYNOPSIS

  use OneEncoding::CORE 'cp932';

=head1 DESCRIPTION



=head2 EXPORT

None by default.

=head1 SEE ALSO


=head1 AUTHOR

Masatsuyo Takahashi, E<lt>cpmuser0@mail1.accsnet.ne.jpE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by A. U. Thor

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.16.3 or,
at your option, any later version of Perl 5 you may have available.

=cut
