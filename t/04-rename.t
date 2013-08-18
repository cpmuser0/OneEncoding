use strict;
use warnings;

use Test::More tests => 5;
BEGIN {
    use t::TestSetting;
    use_ok( 'OneEncoding', $ENCODING );
}

my $file = 't/data/表示能力.csv';
{
    open my $csv, "> $file" or die;
    print $csv "表示能力\n";
    close $csv;
}

stat( $file );
ok( -e _, "file exists" );

rename $file, "$file.tmp";

stat( $file );
ok( !-e _, "file does not exists" );

stat( "$file.tmp" );
ok( -e _, "file exists" );

unlink "$file.tmp";
stat( $file );
ok( !-e _, "file does not exists" );
