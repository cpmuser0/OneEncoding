no strict;
use warnings;

use Test::More tests => 6;
use t::TestSetting;
use OneEncoding "auto";

{
    open CSV, '> t/data/�\���\��.csv' or die;
    print CSV '�\���\��', "\n";
    close CSV;
}

{
    open CSV, 't/data/�\���\��.csv' or die;
    ok( CSV, "open - old style" );

    my $in = 0;
    my $match = 0;
    while ( <CSV> )
    {
        ++$in;
        if ( /�\���\��/ )
        {
            print;
            ++$match;
        }
    }

    close CSV;

    ok( $in, "number of input records: $in" );
    is( $match, $in, "number of matched records: $match" );
}

use strict;
{
    open my $csv, '> t/data/�\���\��.csv' or die;
    print $csv '�\���\��', "\n";
    print $csv "�\���\��\n";
    print $csv q{�\���\��}, "\n";
    print $csv qq{�\���\��\n};
    print $csv <<HEREDOC;
�\���\��
HEREDOC
    print $csv <<'HEREDOC';
�\���\��
HEREDOC
    close $csv;
}

{
    open my $csv, 't/data/�\���\��.csv' or die;
    ok( $csv, "open - modern style" );

    my $in = 0;
    my $match = 0;
    while ( <$csv> )
    {
        ++$in;
        if ( qr/�\���\��/ )
        {
            print;
            ++$match;
        }
    }

    close $csv;

    ok( $in, "number of input records: $in" );
    is( $match, $in, "number of matched records: $match" );
}
