@rem = '--*-Perl-*--
@echo off
@rem C:\ModernPerl\perl\bin\perl.exe -x -S %0 %*
jperl -x -S %0 %*
if NOT "%COMSPEC%" == "%SystemRoot%\system32\cmd.exe" goto endofperl
if %errorlevel% == 9009 echo You do not have Perl in your PATH.
if errorlevel 1 goto script_failed_so_exit_with_non_zero_val 2>nul
goto endofperl
@rem ';
#!perl
#line 12

my $log;
BEGIN {
    my $pid = $$;
    my $logfile = "D:\\svn\\temp\\hook-$pid.log";
    open $log, "> $logfile" or die;
}

use strict;
use MUS::StdLog -handle => $log;
use Subversion::RepoHandler;

$| = 1;

my $repo = Subversion::RepoHandler->new( @ARGV );
$repo->update;

1;

__END__
:endofperl
