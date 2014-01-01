package OneEncoding;

use 5.010001;
use strict;
use warnings;
use overload;
use feature qw( state );
use Encode qw( find_encoding _utf8_on );
use Filter::Util::Call;

our $VERSION    = '0.08';

my $init_encoding;
my $init_enc;

sub get_init_encoding {
    if ( wantarray ) {
        ( $init_encoding, $init_enc );
    }
    else {
        $init_encoding;
    }
}

sub import {
    my $class = shift;
    my $encoding = shift;

    my $caller = caller;

    if ( !defined $encoding or $encoding eq "auto" ) {
        $encoding = $init_encoding // "sjis_escape";
    }

    $init_encoding //= $encoding;

    $class->import_impl( $caller, $init_encoding );
}

sub import_impl {
    my $class = shift;
    my ( $caller, $encoding ) = @_;

    if ( $encoding eq "sjis_escape" ) {
        use_sjis_bytes_proc();
    }
    else {
        use_unicode_chars_proc( $caller, $encoding );
    }
}

sub filter {
    my $self = shift;
    $self->();
}

sub use_sjis_bytes_proc {
    filter_add( bless sub {
            # read the whole source code into the topic variable
            my $status;
            my $count = 0;
            my $lines = "";
            while ( $status = filter_read() ) {
                return $status if $status < 0;

                $lines .= $_;
                $_ = "";
                $count++;
            }
            $_ = $lines;

            # the following escaping is necessary for the Perl Parser
            # to compile source files including CP932 kanji literals
            # such as '発表' where the trailing byte of the last kanji
            # is \, i.e. chr( 0x5c ).
            #
            # L\ => L\\
            s/ ( [\x81-\x9f\xe0-\xef] )( \\ )/$1\\$2/gx;

            return $count;
        }
    );

    overload::constant(
        q  => sub {
                # print Dumper( \@_ );
                my ( $c, undef, $q ) = @_;
                $c =~ s/ ( [\x81-\x9f\xe0-\xef] ) \\ ( \\ ) /$1$2/gx;

                if ( $q eq 'qq' )
                {
                    $c =~ s/ (\\[abnr]) / eval( '"' . $1 . '"' ) /gex;
                }

                $c;
            },

        qr => sub {
                # print Dumper( \@_ );
                my ( $c, undef, $q ) = @_;
                $c =~ s/ ( [\x81-\x9f\xe0-\xef] ) ( [\[\]\{\}\|] ) /$1\\$2/gx;
                $c;
            },
    );
}

sub use_unicode_chars_proc {
    my ( $caller, $encoding ) = @_;

    state $import_count;

    ++$import_count;

    if ( $import_count == 1 ) {
        $init_encoding //= $encoding;
        $init_enc = find_encoding( $encoding );

        binmode STDIN,  ":encoding($encoding)";
        binmode STDOUT, ":encoding($encoding)";
        binmode STDERR, ":encoding($encoding)";

        tie_ENV( $init_enc );
    }

    require OneEncoding::CORE;
    OneEncoding::CORE::override_by_encoding_funcs( $caller, $encoding, $init_enc );
    OneEncoding::CORE::decode_vars( $init_enc );

    require utf8;   # to fetch $utf8::hint_bits
    $^H |= $utf8::hint_bits;

    filter_add( bless sub {
            # read the whole source code into the topic variable
            my $status;
            my $count = 0;
            my $lines = "";
            while ( $status = filter_read() ) {
                return $status if $status < 0;

                $lines .= $_;
                $_ = "";
                $count++;
            }
            $_ = $init_enc->decode( $lines );

            s/ ^ ([^#']*?) -(\w) \s+ ( \$\w+ | '[^']*' | "[^"]*" ) /$1 sub { stat( $3 ); -$2 _ }->() /mgx;

            s/ ( \b local \s* \( \s* %ENV \s* \) ) /tie_ENV( $1 )/gx;

            return $count;
        }
    );

}

sub tie_ENV ($$) {
    my $enc = shift;

    require OneEncoding::ENV;

    my %env;
    tie %env, "OneEncoding::ENV", \%ENV, $enc;

    *main::ENV = \%env;
}

1;
__END__

=head1 NAME

OneEncoding - to make life easier in one-encoding environment

=head1 SYNOPSIS

  use OneEncoding 'sjis_escape';
  use OneEncoding 'cp932';
  use OneEncoding 'auto';
  use OneEncoding;

=head1 DESCRIPTION

Note that this text is UTF8-encoded.

Suppose you are using Japanese on Windows with default encoding CP932
and you print a double-quoted Kanji literal such as "能力"
Then You get a broken literal "迫ﾍ" displayed on console.
This is a situation called mojibake in Japanese.

OneEncoding module is to avoid mojibake and other charater code related
troubles.

The troubles are caused by the fact that the second bytes of some of the
CP932 multi-byte characters coinside with one of special characters in
Perl syntax, such as \, [, ], {, }, etc.

There are two approaches to avoid such troubles. One is byte-oriented
and the other is character-oriented.

Byte-oriented approach avoids mojibake by inserting escape character \
before each special character to indicate it is not special in that case.

Character-oriented approach avoids troubles by decoding CP932 source
text into perl-internal unicode. Internal code characters are safe
against above-memtioned troubles because they are interpreted character-
wise, not byte-wise.

If you deside to take byte-oriented approach, then use OneEncoding with
'sjis_escape'. Otherwise, use OneEncoding with 'cp932'.

In the other two usages, namely, use OneEncoding with 'auto' or without
any parameters, which are supposed to be used in modules, the approach
follows the first-used parameter of OneEncoding.

When the first-used parameter is 'auto' or the first use is without
parameter, then the default is 'sjis_escape'.

=head2 EXPORT

None by default.

=head1 SEE ALSO


=head1 AUTHOR

Masatsuyo Takahashi, E<lt>cpmuser0@mail1.accsnet.ne.jpE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Masatsuyo Takahashi

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.16.3 or,
at your option, any later version of Perl 5 you may have available.

=cut
