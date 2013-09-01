use strict;
use warnings;

use Test::More tests => 4;
BEGIN {
    use t::TestSetting;
    use_ok( 'OneEncoding', $ENCODING );
    use_ok( 't::TestUseInModule' );
}

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
