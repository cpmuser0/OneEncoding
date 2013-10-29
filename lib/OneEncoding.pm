package OneEncoding;

use 5.010001;
use strict;
use warnings;
use Encode;
use Filter::Util::Call;

our $VERSION    = '0.06';

my $init_encoding;

sub import
{
    my $class = shift;
    my $encoding = shift;

    my $caller = caller;

    if ( $encoding eq "auto" )
    {
        $encoding = $init_encoding // "sjis_escape";
    }

    $init_encoding //= $encoding;

    require Filter::Simple;

    if ( $encoding eq "sjis_escape" )
    {
        my $import_sub  = Filter::Simple::gen_filter_import(
                $caller,
                sub
                {
                    # L\ => L\\
                    s/([\x81-\x9f]|[\xe0-\xef]])( \\ )/$1\\$2/gx;

                    # LR => L\R
                    s/([\x81-\x9f]|[\xe0-\xef]])([ \@ \[ \] \^ \{ \| \} ])/$1\\$2/gx;
                },
                undef,
            );
        $import_sub->( $caller );
        return;
    }

    if ( $caller eq "main" )
    {
        binmode STDIN,  ":encoding($encoding)";
        binmode STDOUT, ":encoding($encoding)";
        binmode STDERR, ":encoding($encoding)";

        tie_env( $encoding );
    }

    eval <<EVAL;
package $caller;
use OneEncoding::CORE '$encoding';
EVAL

    require utf8;   # to fetch $utf8::hint_bits
    $^H |= $utf8::hint_bits;

    my $enc = find_encoding( $encoding );

    my $import_sub  = Filter::Simple::gen_filter_import(
            $caller,
            sub
            {
                $_ = $enc->decode( $_ );
                # convert -e $file to sub{ stat $file; -e _ }->()
                s/ -(\w) \s+ ( \$\w+ | '[^']*' | "[^"]*" ) /sub{ stat($2); -$1 _ }->()/gx;  # '
            },
            undef,
        );

    $import_sub->( $caller );
}

sub tie_env
{
    my $encoding = shift;

    require OneEncoding::ENV;
    OneEncoding::ENV->import( $encoding );

    my %env;
    tie %env, "OneEncoding::ENV";

    *main::ENV = \%env;
}

1;
__END__

=head1 NAME

OneEncoding - to make life easier in one-encoding environment

=head1 SYNOPSIS

  use OneEncoding 'cp932';

=head1 DESCRIPTION



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
