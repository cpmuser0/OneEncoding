package MUS::StdLog;

use OneEncoding 'auto';
use 5.010001;
use strict;
use warnings;
use Env qw( MUS_DEBUG MUS_LOG_TRUNCATE );
use MUS::LogHandle 1.00;
use OneEncoding::Util qw( should_be_decoded );

our $VERSION = '1.05';

my ( $encoding, $enc ) = OneEncoding::get_init_encoding;

my $fh;
my $mirror;

sub import
{
    return if defined $fh;
    my $class = shift;

    my %opt = (
        -die_trap   =>  \&_die_trap,
        -warn_trap  =>  \&_warn_trap,
    );

    while ( @_ and $_[0] =~ /^-/ )
    {
        my $key = shift;
        $opt{ $key } = shift;
    }

    my $logfile_name;

    if ( defined $opt{-name} and $opt{-name} eq 'step' )
    {
        my $stepid = $ENV{MUS__STEPID};
        unless ( $stepid )
        {
            warn <<NO_STEPID;
ステップＩＤがセットされていません。
ステップＩＤは "unknown.step" になります。
NO_STEPID
            $stepid = "unknown.step";
        }
        $logfile_name = "$stepid.log";
    }
    elsif ( defined $opt{-handle} )
    {
        $fh = $opt{-handle};
    }
    else
    {
        $logfile_name = $0;
        $logfile_name =~ s% ^ .+ (?<!$_KanjiLeft_) [\\/] %%x;   # フォルダ名を削除
        $logfile_name =~ s/\.\w+$/.log/;
    }

    my $out_option = $MUS_LOG_TRUNCATE ? ">" : ">>";

    if ( defined $enc )
    {
        require Encode;
        unless ( $fh )
        {
            CORE::open $fh, "$out_option:encoding($encoding)", $enc->encode( $logfile_name ) or die $!;
        }
        if ( $MUS_DEBUG )
        {
            CORE::open $mirror, "$out_option&:encoding($encoding)", \*STDERR or die $!;
        }
    }
    else
    {
        unless ( $fh )
        {
            CORE::open $fh, "$out_option $logfile_name" or die $!;
        }
        if ( $MUS_DEBUG )
        {
            CORE::open $mirror, "$out_option&", \*STDERR or die $!;
        }
    }

    my $fh_save = select $fh; $| =1;
    if ( defined $mirror )
    {
        select $mirror; $| =1;
    }
    select $fh_save;

    tie *STDOUT, 'MUS::LogHandle', $fh, $mirror;
    tie *STDERR, 'MUS::LogHandle', $fh, $mirror;
    tie *STDIN,  'MUS::LogHandle', $fh, $mirror;

    if ( !$SIG{__DIE__} and ref($opt{-die_trap}) eq 'CODE' )
    {
        # 未設定の場合に限り、設定する。
        $SIG{__DIE__} = $opt{-die_trap};
    }
    if ( !$SIG{__WARN__} and ref($opt{-warn_trap}) eq 'CODE' )
    {
        # 未設定の場合に限り、設定する。
        $SIG{__WARN__} = $opt{-warn_trap};
    }
}

sub _die_trap
{
    my $msg = shift;
    return if $msg =~ /during global destruction.\s*$/;

    _decode_message_if_you_need( \$msg ) if defined $enc;

    if ( $^S )
    {
        # eval の中の場合。
        chomp $msg;
        CORE::die( "$msg\n" );
    }
    else
    {
        # eval の中でない場合
        print STDERR $msg;
        exit( $! || $?>>8 || 255 );
        # Thanks to:
        # http://stackoverflow.com/questions/7820344/perl-how-to-die-with-no-error-message
    }
}

sub _warn_trap
{
    my $msg = shift;

    _decode_message_if_you_need( \$msg ) if defined $enc;

    print STDERR $msg;
}

sub _decode_message_if_you_need
{
    my $msg = shift;
    # 改行のないメッセージに追加されるプログラムパス名が
    # decode されていないため、decode する。
    # （できれば、die/warn が参照するプログラムパス名をdecodeした方がよいが）
    $$msg =~ s/at ( \s+ .+ ) (line \s+ \d+ \.?) $/ "at". _decode_if_not_yet( $1 ) . $2/sxe;
}

sub _decode_if_not_yet
{
    my $f = shift;
    if ( should_be_decoded( $f ) )
    {
        my $d = $enc->decode( $f );
        $d;
    }
    else
    {
        $f;
    }
}

END
{
    close $fh if $fh;
    close $mirror if $mirror;
}

1;
__END__
=head1 NAME

MUS::StdLog - ＭＵＳのための標準ログ出力

=head1 SYNOPSIS

【書式１】  use MUS::StdLog;

【書式２】  use MUS::StdLog -name => 'step';

=head1 DESCRIPTION

このモジュールを use することで、標準出力と標準エラー出力の出力が
ログファイルへの出力に切り替わる。
ログファイルの命名規則は、書式１と書式２で次のように異なる。

書式１の場合は、use しているメインスクリプトのファイル名（ディレクトリを
除く）の拡張子を .log に変更したものになる。

書式２の場合は muexec コマンドで起動された場には、環境変数 MUS__STEPID
によって親プロセスから伝達されたジョブステップＩＤに 拡張子 .log を付与
したものになる。 muexec コマンド以外で起動され、環境変数 MUS__STEPID が
未設定の場合は、unknown.step.log になる。

=head1 ENVIRONMENT VARIABLE

MUS_DEBUG         ゼロ以外をセットすると標準出力へのミラーが有効になる。

MUS_LOG_TRUNCATE  ゼロ以外をセットすると前回のログに上書き

=head2 EXPORT

None by default.


=head1 SEE ALSO

  MUS::LogHandle
  MUS::Exec

=head1 AUTHOR

A. U. Thor, E<lt>takahashi@mtec-institute.co.jpE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Masatsuyo Takahashi

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.1 or,
at your option, any later version of Perl 5 you may have available.


=head1 HISTORY

  2014-03-18 0.04  高橋（正）
    1) 環境変数 MUS__STEPID を設定しない場合のログがカレントフォルダに
       記録されるようにログファイル名からフォルダ名の修飾を削除。

  2014-05-23 0.04  高橋（正）
    1) __END__ 以下のドキュメントを追加。

=cut
