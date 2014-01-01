package OneEncoding::ENV;

use 5.010001;
use strict;
use warnings;
use Encode;
our $VERSION = '0.02';

sub TIEHASH
{
	my $class = shift;
	# print "DEBUG: $class, @_\n";
	bless [ @_ ], $class;
}

sub STORE
{
    my ( $self, $key, $value ) = @_;
    # print "DEBUG(STORE): key=$key\n";
    $self->[0]->{ $key } = $self->[1]->encode( $value );
}

sub FETCH
{
    my ( $self, $key ) = @_;
    # print "DEBUG(FETCH): key=$key\n";
    my $value = $self->[0]->{$key};
    defined $value ? $self->[1]->decode( $value ) : undef;
}

sub FIRSTKEY
{
    my ( $self, $key ) = @_;
    # print "DEBUG(FETCH): key=$key\n";
    my $env = $self->[0];
    my $a = scalar keys %$env;
    each %$env;
}

sub EXISTS
{
    my ( $self, $key ) = @_;
    exists $self->[0]->{$key};
}

sub DELETE
{
    my ( $self, $key ) = @_;
    delete $self->[0]->{$key};
}

sub CLEAR
{
    my ( $self, $key ) = @_;
    %{ $self->[0] } = ();
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
