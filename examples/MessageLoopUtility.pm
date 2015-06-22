#-------------------------------------------------------------------------------
=comment

    Win32::OLE->WithEvets のためのユーティリティ

    Copyright (C) 2010 MTEC. All rights reserved.

=cut
#-------------------------------------------------------------------------------
package MessageLoopUtility;
use OneEncoding "auto";
use strict;
use vars qw( @ISA @EXPORT_OK );
require Exporter;

@ISA = qw(Exporter);

@EXPORT_OK = qw(
message_loop
);

use Win32::OLE;

sub message_loop
{
    my ( $wait, $last_cond ) = @_;

    my $start = time;
    while ( time - $start < $wait )
    {
        Win32::OLE->SpinMessageLoop;
        if ( $last_cond and $last_cond->() )
        {
            sleep 1;
            last;
        }
    }
}

1;
