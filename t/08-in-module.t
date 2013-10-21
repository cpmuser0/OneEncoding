use strict;
use warnings;

use Test::More tests => 2;
use t::TestSetting;
use OneEncoding $ENCODING;
use t::TestUseInModule;

my $file = 't/data/�\���\��.csv';
{
    open my $csv, "> $file" or die;
    print $csv "�\���\��\n";
    close $csv;
}

TestUseInModule::case_01_input();

{
    open my $csv, $file or die;
    my $line = <$csv>;
    print $line;
    like( $line, qr/�\���\��/, "input & regex");
    close $csv;
}
