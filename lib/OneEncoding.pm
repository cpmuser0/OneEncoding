package OneEncoding;

use 5.010001;
use strict;
use warnings;
use Encode;
use Filter::Util::Call;

our $VERSION    = '0.03';

my $init_encoding;
my $sjis_escape_sub;
my $one_encoding_sub;

sub import
{
    my $class = shift;
    my $encoding = shift;

    my $caller = caller;

    if ( !defined $encoding or $encoding eq "auto" )
    {
        $encoding = $init_encoding // "sjis_escape";
    }

    $init_encoding //= $encoding;

    require Filter::Simple;

    if ( $encoding eq "sjis_escape" )
    {
        $sjis_escape_sub  //= filter_only(

                quotelike => sub
                {
                    if ( !/^(<<)?'/ ) # if it does not begin with '
                    {
                        # print "DEBUG:$_:\n";
                        # L\ => L\\
                        s/([\x81-\x9f]|[\xe0-\xef]])( \\ )/$1\\$2/gx;

                        # LR => L\R
                        s/([\x81-\x9f]|[\xe0-\xef]])([ \@ \` \[ \] \^ \{ \| \} ])/$1\\$2/gx;
                    }
                },

            );
        $sjis_escape_sub->( $caller );
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

    $one_encoding_sub  //= filter_only(

            all  => sub { $_ = $enc->decode( $_ ) },

            executable  => sub {
                # convert -e $file to sub{ stat $file; -e _ }->()
                s/ -(\w) \s+ ( \$\w+ | '[^']*' | "[^"]*" ) /sub{ stat($2); -$1 _ }->()/gx;  # '
            },

        );

    $one_encoding_sub->( $caller );
}

sub filter_only
{
    # This sub is borrowed from Filter::Simple::FILTER_ONLY
    # removing the args check and the trailing redefines.

    my @transforms;
    while (@_ > 1) {
        my ($what, $how) = splice(@_, 0, 2);
        push @transforms, Filter::Simple::gen_std_filter_for($what,$how);
    }
    my $terminator = shift;

    my $multitransform = sub {
        foreach my $transform ( @transforms ) {
            $transform->(@_);
        }
    };

    # no redefines

    Filter::Simple::gen_filter_import( "_DUMMY_", $multitransform, $terminator );
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

  use OneEncoding 'sjis_escape';
  use OneEncoding 'cp932';
  use OneEncoding 'auto';
  use OneEncoding;

=head1 DESCRIPTION

Note that this text is CP932-encoded.

Suppose you are using Japanese on Windows with default encoding CP932
and you print a double-quoted Kanji literal such as "”\—Í".
Then You get a broken literal "”—Í" displayed on console.
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
