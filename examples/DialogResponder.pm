#-------------------------------------------------------------------------------
=comment

    ダイアログの操作

    Copyright (C) 2011 MTEC. All rights reserved.

=cut
#-------------------------------------------------------------------------------
package DialogResponder;
use OneEncoding "auto";

require 5.18.1;
use strict;
require Exporter;
use Encode;

our @ISA = qw(Exporter);

our @EXPORT = qw(
RespondDialog
);

our $VERSION = 0.03;

use Win32::OLE;
use Win32::GuiTest qw( FindWindowLike GetWindowText SetForegroundWindow SendKeys PushButton );
use MDL::Date qw($TIME);
use Encode;

sub RespondDialog
{
    my ( $keys, $text ) = @_;

    $text ||= "^Microsoft Internet Explorer";

    open my $log, ">> RespondDialog.log";

    my $sent;
    my $retry;

    RESPOND: {
        sleep 1;

        while ( my @windows = FindWindowLike( 0, $text ) )
        {
            print "GetWindowText: ", GetWindowText($windows[0]), "\n";

            SetForegroundWindow($windows[0]);
            foreach my $key ( split( ";", $keys ) )
            {
                sleep(1);
                SendKeys( $key );
                ++$sent;
                sleep(1);
            }
        }

        if ( !$sent and ++$retry <= 3 )
        {
            print $log "$TIME retry RESPOND\n";
            redo RESPOND;
        }

        print $log "$TIME sent $sent\n";
    }

    close $log;
}

1;
