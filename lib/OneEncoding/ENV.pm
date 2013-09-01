package OneEncoding::ENV;

use 5.010001;
use strict;
use warnings;
use Encode;
use Tie::Hash;
our $VERSION = '0.01';
our @ISA = qw( Tie::StdHash );

my $genv ||= \%ENV;
my $encoding;

sub import
{
    my $class = shift;
    $encoding = shift;
}

sub STORE
{
    my ( $self, $key, $value ) = @_;
    $genv->{ $key } = encode( $encoding, $value );
}

sub FETCH
{
    my ( $self, $key ) = @_;
    decode(  $encoding, $genv->{$key} );
}

1;
__END__

=head1 NAME

OneEncoding::ENV - hash to override %ENV

=head1 SYNOPSIS

  use OneEncoding::ENV 'cp932';

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
