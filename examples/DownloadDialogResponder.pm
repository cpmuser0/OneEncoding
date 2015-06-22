#-------------------------------------------------------------------------------
=comment

    ファイル・ダウンロード・ダイアログの操作

    Copyright (C) 2010-2011 MTEC. All rights reserved.

=cut
#-------------------------------------------------------------------------------
package DownloadDialogResponder;
use OneEncoding "auto";

require 5.18.1;
use strict;
require Exporter;

our @ISA = qw(Exporter);

our @EXPORT = qw(
RespondToDownloadDialog
);

our $VERSION = 0.04;

use Win32::OLE;
use Win32::GuiTest qw( FindWindowLike GetWindowText SetForegroundWindow SendKeys PushButton );
use MessageLoopUtility qw( message_loop );
use MDL::Date qw($TIME);

sub RespondToDownloadDialog
{
    my ( %opts ) = @_;

    # print "DEBUG: RespondToDownloadDialog( @_ )\n";

    my $retry;

    SAVE0: {
        sleep 1;

        my @windows = FindWindowLike( 0, "^ファイル" );

        if ( @windows )
        {
            SetForegroundWindow($windows[0]);
            print "GetWindowText: ", GetWindowText($windows[0]), "\n";

            SAVE1: {
                # PushButton("保存",1);
                message_loop( 1 );

                SendKeys( "%S" );

                message_loop( 1 );

                @windows = FindWindowLike( 0, "^名前を" );
                if ( @windows )
                {
                    print "DEBUG: 名前を (1)\n";

                    SetForegroundWindow( $windows[0] );

                    SAVE2: {
                        message_loop( 1 );

                        SendKeys( "%S" );

                        message_loop( 1 );

                        @windows = FindWindowLike( 0, "^名前を" );
                        if ( @windows )
                        {
                            print "DEBUG: 名前を (2)\n";

                            # SetForegroundWindow( $windows[0] );
                            message_loop( 1 );

                            SendKeys( "%Y" );

                            message_loop( 1 );

                            $retry = 999;
                            print "$TIME redo SAVE2 $retry\n";
                            redo SAVE2;
                        }
                        else
                        {
                            my @windows_f = FindWindowLike( 0, "^ファイル" );
                            if ( @windows_f )
                            {
                                print "GetWindowText: ", GetWindowText($windows_f[0]), "\n";

                                if (++$retry <= 3)
                                {
                                    print "$TIME redo SAVE2 $retry\n";
                                    sleep 1;
                                    redo SAVE2;
                                }
                            }
                            else
                            {
                                print "DEBUG: May be OK.\n";
                                # print "DEBUG: done? 1 $retry\n";
                                return 1;
                            }
                        }
                    }
                }
                else
                {
                    my @windows_f = FindWindowLike( 0, "^ファイル" );
                    if ( @windows_f )
                    {
                        if (++$retry <= 50)
                        {
                            print "$TIME redo SAVE1\n";
                            sleep 1;
                            redo SAVE1;
                        }
                        else
                        {
                            message_loop( 1 );
                            SendKeys( "~" );
                            message_loop( 1 );
                            return 0;
                        }
                    }
                    # print "DEBUG: done? 2 $retry\n";
                }
            }
        }
        else
        {
            if (++$retry <= 20)
            {
                print "$TIME redo SAVE0\n";
                sleep 1;
                redo SAVE0;
            }
            else
            {
                return undef;
            }
        }
    }
}

1;
