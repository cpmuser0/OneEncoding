use strict;
use warnings;

use Test::More tests => 8;
BEGIN {
    use t::TestSetting;
    use_ok( 'OneEncoding::Filter' );
    use_ok( 'OneEncoding::CORE', $ENCODING );
}

my $file = 't/data/表示能力.csv';
{
    open my $csv, "> $file" or die;
    print $csv "表示能力\n";
    close $csv;
}

ok( -e $file, "stat existent" );
ok( -e 't/data/表示能力.csv', "stat 'existent'" );
ok( -e "t/data/表示能力.csv", 'stat "existent"' );

$file = 'non_existent_file_name';
ok( ! -e $file, "stat non-existent" );
ok( ! -e 'non_existent_file_name', "stat 'non-existent'" );
ok( ! -e "non_existent_file_name", 'stat "non-existent"' );
