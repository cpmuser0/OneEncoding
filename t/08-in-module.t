use strict;
use warnings;

use Test::More tests => 2;
use t::TestSetting;
use OneEncoding $ENCODING;
use t::TestUseInModule;

my $file = 't/data/表示能力.csv';
{
    open my $csv, "> $file" or die;
    print $csv "表示能力\n";
    close $csv;
}

TestUseInModule::case_01_input();

{
    open my $csv, $file or die;
    my $line = <$csv>;
    print $line;
    like( $line, qr/表示能力/, "input & regex");
    close $csv;
}
