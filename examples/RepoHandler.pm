#-------------------------------------------------------------------------------
=comment

    Subversion::RepoHandler

        post-commmit hook によってコミットされたブックから
        VBA モジュールをエクスポートして閲覧用のリポジトリに
        反映するためのモジュール。

    Copyright (C) 2015 MTEC. All rights reserved.

=cut
#-------------------------------------------------------------------------------
package Subversion::RepoHandler;

#-------------------------------------------------------------------------------
#   モジュールと定数の宣言
#-------------------------------------------------------------------------------
use strict;
require 5.18.2;
require Exporter;

our $VERSION = 0.01;

our @ISA = qw( Exporter );
our @EXPORT = qw(
    set_svn_hook_log
    update_vba_browser_repo
);

use Subversion::Excel;

#-------------------------------------------------------------------------------
#   VBAモジュールのエクスポート用変換ルール
my @ExportRules = (
    [   qr{^(trunk/\w+)}    => "trunk/export-book"  ],
);

=comment

    以下では、変数名を次のように使い分ける。

    $book_path      trunk/env/tool.xlsm
    $export_path    trunk/book-export/tool-xlsm （上記ルール適用後 .xlsm => -xlsm）
    $export_url     file://localhost/D:/svn/repos/sample/trunk/env/tool-xlsm
                                                （リポジトリを付けて URL に変換）

=cut
#--------------------------------------------------------------------------------

my $SvnTempDir = $ENV{SVN_TEMP_DIR} || 'D:\svn\temp';

mkdir $SvnTempDir, 0777 unless -e $SvnTempDir;
-e $SvnTempDir or die;

#  属性の位置         属性の意味                        値の例
#-------------------------------------------------------------------------------
my $_DIR    = 0;    # リポジトリ外の作業用のフォルダ    D:\svn\temp\1234  （1234は PID）
my $_REP    = 1;    # リポジトリフォルダ                D:\svn\repos\sample
my $_REV    = 2;    # リビジョン                        65
my $_TXN    = 3;    # 
my $_URL    = 4;    # リポジトリURL         file://localhost/d:/svn/repos/sample

#-------------------------------------------------------------------------------
#   コンストラクタ
#-------------------------------------------------------------------------------
sub new
{
    my $class       = shift;

    my $pid = $$;
    my $temp_dir    = "$SvnTempDir\\$pid";

    _remove_reccursively_forced( $temp_dir );
    mkdir $temp_dir, 0777;

    my ( $rep, $rev, $txn ) = @_;

    my $url = "file://localhost/$rep";
    $url =~ s%\\%/%g;

    bless [ $temp_dir, $rep, $rev, $txn, $url ];
}

#-------------------------------------------------------------------------------
#   デストラクタ
#-------------------------------------------------------------------------------
sub DESTROY
{
    my $self = shift;
    my ( $dir ) = @$self[ $_DIR ];

    # _remove_reccursively_forced( $dir );
}

#-------------------------------------------------------------------------------
#   post-commit-hook の更新制御
#-------------------------------------------------------------------------------
sub update
{
    my $self = shift;

    my ( $repositry, $revision ) = @$self[ $_REP, $_REV  ];

    print "hook args = ( $repositry, $revision )\n";

    open my $svn, "svnlook changed -r $revision $repositry |";

    while ( my $line = <$svn> )
    {
        chomp $line;
        print "$line\n";
        next unless $line =~ /^ (\w) \s+ (.+\.xlsm) $ /x;

        my ( $ope, $book_path ) = ( $1, $2 );
        my $export_path = $book_path;
        my $is_export_target;
        foreach my $rule ( @ExportRules )
        {
            next unless $export_path =~ s/$rule->[0]/$rule->[1]/;
            $export_path =~ s/\.(xlsm)$/-$1/i;
            $is_export_target = 1;
            last;
        }

        next unless $is_export_target;

        print "DEBUG: ( $ope, $book_path, $export_path )\n";

        $self->update_by_book( $ope, $book_path, $export_path );
    }

    close $svn;
}

#-------------------------------------------------------------------------------
#   Excelマクロブックによる更新制御
#-------------------------------------------------------------------------------
my $excel;
sub update_by_book
{
    my $self = shift;
    my ( $dir )  = @$self[ $_DIR ];

    my ( $ope, $book_path, $export_path ) = @_;

    print "DEBUG(update_by_book): ( $ope, $book_path, $export_path )\n";

    print "update modules in ( $ope, $book_path ).\n";
    print "Exporting vba modules.\n";

    # check out or import
    if ( $ope eq "D" )
    {
        # book_path が削除された場合
        $self->repo_remove_dir( $export_path );
    }
    else
    {
        my $module_dir = "$dir\\module_dir";
        $self->export_modules( $book_path, $module_dir );

        $self->repo_commit_dir( $book_path, $module_dir, $export_path );
    }
}

#-------------------------------------------------------------------------------
#   リポジトリ内の book-export フォルダの削除r
#-------------------------------------------------------------------------------
sub repo_remove_dir
{
    my $self = shift;
    my ( $url )  = @$self[ $_URL ];
    my ( $export_path ) = @_;
    print "DEBUG(repo_remove_dir): @_\n";

    my $cmd = qq(svn delete $url/$export_path -m "により削除");
    print "$cmd\n";
    my $ret = system( $cmd );
    print "delete ret=$ret\n";
}

#-------------------------------------------------------------------------------
#   Excelマクロブックの SVN-EXPORT およびモジュールの VBE-EXPORT
#-------------------------------------------------------------------------------
sub export_modules
{
    my $self = shift;
    my ( $dir, $rev, $url ) = @$self[ $_DIR, $_REV, $_URL ];
    my ( $book_path, $module_dir ) = @_;

    print "DEBUG(export_modules): @_\n";

    my $cmd = "svn export -r $rev $url/$book_path $dir";
    print "$cmd\n";
    my $ret = system( $cmd );
    print "export ret=$ret\n";
    $ret == 0 or die;

    mkdir $module_dir, 0777;

    my $bookname = ( split( "/", $book_path ) )[-1];

    ExportModules( "$dir\\$bookname", $module_dir );
}

#-------------------------------------------------------------------------------
#   ワーキングコピーの用意とコミット
#-------------------------------------------------------------------------------
sub repo_commit_dir
{
    my $self = shift;
    my ( $dir, $rev, $url ) = @$self[ $_DIR, $_REV, $_URL ];
    my ( $book_path, $module_dir, $export_path ) = @_;

    print "DEBUG(repo_commit_dir): @_\n";

    # # book-export フォルダのチェックアウトを試みる。
    my $work_dir = "$dir\\work_dir";
    mkdir $work_dir, 0777;
    my $exoort_url = "$url/$export_path";
    my $cmd = "svn checkout $exoort_url $work_dir";
    print "$cmd\n";
    my $ret = system( $cmd );
    print "checkout ret=$ret\n";
    if ( $ret == 0 )
    {
        # book-export フォルダが既存（チェックアウト成功）の場合は、
        # ワーキングコピーを操作してコミットする。
        _reflect_module_dir_to_work_dir( $module_dir, $work_dir );
        # sleep 1;
        my $commit_cmd = qq(svn commit $work_dir -m "post-commit-hook により改訂" );
        my $commit_ret = system( $commit_cmd );
        print "commit_ret=$commit_ret\n";
    }
    else
    {
        # book-export フォルダがない（チェックアウト失敗の）場合は、
        # 作成してインポートする。
        $self->repo_make_dir( $export_path );
        # sleep 1;
        my $import_cmd = qq(svn import $module_dir $exoort_url -m "post-commit-hook によりインポート");
        print "$import_cmd\n";
        my $import_ret = system( $import_cmd );
        print "import ret=$import_ret\n";
    }
}

#-------------------------------------------------------------------------------
#   リポジトリ内の book-export フォルダ作成
#-------------------------------------------------------------------------------
sub repo_make_dir
{
    my $self = shift;
    my ( $url )  = @$self[ $_URL ];
    my ( $export_path ) = @_;
    
    print "DEBUG(repo_make_dir): @_\n";
    my @path = split( "/", $export_path );

    for ( my $i = 0; $i < @path; ++$i )
    {
        my $url_dir = join( "/", $url, @path[0..$i] );
        my $cmd = qq(svn mkdir "$url_dir" -m "post-commit-hook により作成" );
        print "$cmd\n";
        my $ret = system( $cmd );
        print "mkdir ret=$ret\n";
    }
}

#-------------------------------------------------------------------------------
#   ワーキングコピーの用意
#-------------------------------------------------------------------------------
sub _reflect_module_dir_to_work_dir
{
    my ( $from, $to ) = @_;
    print "DEBUG(_reflect_module_dir_to_work_dir): @_\n";

    my @work_dir_entries     = glob( "$to\\*.*" );

    my %entry;

    foreach ( @work_dir_entries )
    {
        print "$_\n";
        my $file = ( split( '\\\\', $_ ) )[-1];
        $entry{ $file }++;
    }

    my @module_dir_entries  = glob( "$from\\*.*" );

    foreach ( @module_dir_entries )
    {
        print "$_\n";
        my $file = ( split( '\\\\', $_ ) )[-1];
        my $to_path = "$to\\$file";
        system( "copy $_ $to_path" );

        if ( exists $entry{ $file } )
        {
            delete $entry{ $file };
        }
        else
        {
            my $cmd = "svn add $to_path";
            my $ret = system( $cmd );
            print "add ret=$ret\n";
        }
    }

    foreach ( sort keys %entry )
    {
        print "$_\n";
        my $file = ( split( '\\\\', $_ ) )[-1];
        my $to_path = "$to\\$file";
        my $cmd = "svn delete $to_path";
        print "$cmd\n";
        my $ret = system( $cmd );
        print "delete ret=$ret\n";
    }
}

#-------------------------------------------------------------------------------
#   utilities
#-------------------------------------------------------------------------------
sub _remove_reccursively_forced
{
    system( "perl -MExtUtils::Command -e rm_rf $_[0]" );
}

1;
