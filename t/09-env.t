use strict;
use warnings;
use Test::More tests => 2;
BEGIN {
    use t::TestSetting;
    use_ok( 'OneEncoding', $ENCODING );
}

$ENV{ TEST_ENV } = "表示能力";

my $file = 't/temp.txt';

system( "echo %TEST_ENV% > $file" );

open my $txt, $file or die;

my $count;
while ( <$txt> )
{
	$count++ if /表示能力/;
}

is( $count, 1, "echo" );

close $txt;

unlink $file;
