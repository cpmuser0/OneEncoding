#-------------------------------------------------------------------------------
=comment

    RunBackGround

    Perl5.8.4 で Thread を使うと異常終了するため、
    代替手段として、子プロセスを作って処理する。

    @todo  Perl5.10.1

    Copyright (C) 2009-2010 MTEC. All rights reserved.

=cut
#-------------------------------------------------------------------------------
package RunBackGround;
use OneEncoding "auto";

require 5.18.1;
use strict;
use Win32::Process;
use Win32;

sub ErrorReport{
    print Win32::FormatMessage( Win32::GetLastError() );
}

sub create_process
{
    my $process;
    Win32::Process::Create($process,
                                $_[0],
                                $_[1],
                                0,
                                NORMAL_PRIORITY_CLASS,
                                ".")|| die ErrorReport();

    $process->Suspend();

    $process
}

sub resume
{
    my $process = shift;
    $process->Resume();
}

sub kill
{
     my ( $process, $exitcode ) = @_;
     $process->Kill( $exitcode )
}

1;

__END__

# Re: Perl Background processes in Windows
# by mpeg4codec (Monk) on Jan 18, 2008 at 22:46 UTC
# The most portable way of doing this that I can think of is to use fork followed by exec.
# Consider the following:

sub run_in_bg
{
    my $pid = fork;
    die "Can't fork a new process" unless defined $pid;

    # child gets PID 0
    if ($pid == 0) {
        exec(@_) || die "Can't exec $_[0]";
    }

    # in case you wanted to use waitpid on it
    return $pid;
}

# You'd call this the same way you'd call system, except now it forks a new process
# before running the first arg.

1;
