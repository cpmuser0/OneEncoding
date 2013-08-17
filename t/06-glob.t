use strict;
use warnings;

use Test::More tests => 2;
BEGIN {
    use t::TestSetting;
    use_ok( 'OneEncoding::CORE', $ENCODING );
}

my $file = 't/data/表示能力.csv';
{
    open my $csv, "> $file" or die;
    print $csv "表示能力\n";
    close $csv;
}

my @files = glob( "t/data/*.csv" );
my $num_grepped = grep{ /表示能力/ } @files;

ok( $num_grepped, "glob" );
