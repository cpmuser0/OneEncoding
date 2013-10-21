use strict;
use warnings;

use Test::More tests => 1;
use t::TestSetting;
use OneEncoding $ENCODING;

my $file = 't/data/�\���\��.csv';
{
    open my $csv, "> $file" or die;
    print $csv "�\���\��\n";
    close $csv;
}

my @files = glob( "t/data/*.csv" );
my $num_grepped = grep{ /�\���\��/ } @files;

ok( $num_grepped, "glob" );
