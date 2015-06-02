#-------------------------------------------------------------------------------
=comment

    Subversion::Excel

        

    Copyright (C) 2015 MTEC. All rights reserved.

=cut
#-------------------------------------------------------------------------------
package Subversion::Excel;

#-------------------------------------------------------------------------------
#   モジュールと定数の宣言
#-------------------------------------------------------------------------------
use strict;
require 5.18.2;
require Exporter;

our $VERSION = 0.01;

our @ISA = qw( Exporter );
our @EXPORT = qw(
    ExportModules
);

use Win32::OLE;

my %ModuleType = (
    1   => "bas",
    2   => "cls",
    3   => "frm",
    100 => "cls",
);

#-------------------------------------------------------------------------------
#   
#-------------------------------------------------------------------------------
my $excel;

sub _init
{
    return if $excel;

    $excel = Win32::OLE->new('Excel.Application', \&Quit);
    if ( my $error = Win32::OLE->LastError )
    {
        print "Can't run Excel: $error\n";
        die;
    }
    else
    {
        print "Excel is ready.\n";
    }
}

#-------------------------------------------------------------------------------
#   Export Modules
#-------------------------------------------------------------------------------
sub ExportModules
{
    my ( $book, $module_dir ) = @_;

    print "DEBUG(ExportModules): ( $book, $module_dir )\n";

    _init();

    $excel->Workbooks->Open( $book ) or die Win32::OLE->LastError;

    my $N = $excel->Workbooks->Count;

    print "N=$N\n";

    my $workbook = $excel->Workbooks( 1 );

    my $M = $workbook->VBProject->VBComponents->Count;

    print "M=$M\n";

    for ( my $j = 1; $j <= $M; ++$j )
    {
        my $component = $workbook->VBProject->VBComponents( $j );
        my $name    = $component->Name;
        my $type    = $component->Type;
        print "type=$type\n";

        if ( $type <= 3 or $type == 100 )
        {
            # 100 はWorksheet の cls
            my $ext     = $ModuleType{ $type };
            my $name    = $component->Name;
            print "\tname=$name\n";
            $component->Export( "$module_dir\\$name.$ext" );
            if ( $ext eq "frm" )
            {
            	unlink "$module_dir\\$name.frx";
            }
        }
    }
}

#-------------------------------------------------------------------------------
#   Quit
#-------------------------------------------------------------------------------
sub Quit
{
    $excel->Quit;
}

1;
