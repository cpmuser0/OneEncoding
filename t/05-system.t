use strict;
use warnings;
use Test::More tests => 2;
BEGIN {
    use t::TestSetting;
    use_ok( 'OneEncoding', $ENCODING );
}

my $file = 't/temp.txt';

system( "echo 表示能力 > $file" );

open my $txt, $file or die;

my $count;
while ( <$txt> )
{
	$count++ if /表示能力/;
}

is( $count, 1, "echo" );

close $txt;

unlink $file;
