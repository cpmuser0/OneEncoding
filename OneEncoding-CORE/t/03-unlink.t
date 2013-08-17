use strict;
use warnings;

use Test::More tests => 3;
BEGIN {
    use t::TestSetting;
    use_ok( 'OneEncoding::CORE', $ENCODING );
}

my $file = 't/data/�\���\��.csv';
{
    open my $csv, "> $file" or die;
    print $csv "�\���\��\n";
    close $csv;
}

stat( $file );
ok( -e _, "file exists" );

unlink( $file );
stat( $file );
ok( !-e _, "file does not exist" );
