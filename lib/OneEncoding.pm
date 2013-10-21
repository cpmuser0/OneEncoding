package OneEncoding;

use 5.010001;
use strict;
use warnings;
use Encode;
use Filter::Util::Call;

our $VERSION    = '0.04';

my $LINENO         = 0;
my $ENCODING       = 1;
my $ENC            = 2;

sub import
{
    my $class = shift;
    my $encoding = shift;
    $encoding or die "Usage: use OneEncodingE 'ENCODING';";
    my $caller = caller;

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

	require utf8;		# to fetch $utf8::hint_bits
	$^H |= $utf8::hint_bits;

    my $enc = find_encoding( $encoding );
    filter_add( bless [ 0, $encoding, $enc ] );
}

sub filter
{
    my $self = $_[0];

    my $status = filter_read();

    if ( $status > 0 )
    {
    	$_ = $self->[$ENC]->decode( $_ );
        # convert -e $file to sub{ stat $file; -e _ }->()
        s/ -(\w) \s+ ( \$\w+ | '[^']*' | "[^"]*" ) /sub{ stat($2); -$1 _ }->()/gx;  # '
    }

    $status;
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
