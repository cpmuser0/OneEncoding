package TestUseInModule;
use Test::More;
use OneEncoding "cp932";

sub case_01_input
{
    my $file = 't/data/表示能力.csv';
    open my $csv, $file or die;
    my $line = <$csv>;
    like( $line, qr/表示能力/, "input & regex");
    close $csv;
}

1;
