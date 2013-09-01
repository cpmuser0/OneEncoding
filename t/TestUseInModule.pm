package TestUseInModule;
use Test::More;
use OneEncoding "cp932";

sub case_01_input
{
    my $file = 't/data/�\���\��.csv';
    open my $csv, $file or die;
    my $line = <$csv>;
    like( $line, qr/�\���\��/, "input & regex");
    close $csv;
}

1;
