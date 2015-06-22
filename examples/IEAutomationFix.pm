package IEAutomationFix;

require Exporter;

our @ISA = qw( Exporter );
our @EXPORT = qw(
    GetAllTables
);

use Win32::IEAutomation::Table;

sub GetAllTables
{
    my $self = shift;
    my $agent = $self->{agent};
    my @links_array;
    my $links = $agent->Document->all->tags("table");
    for (my $n = 0; $n < $links->length; $n++){
        my $link_object = Win32::IEAutomation::Table->new();
        $link_object->{table} = $links->item($n);
        $link_object->{parent} = $self;
        push (@links_array, $link_object);
    }
    return @links_array;
}

1;
