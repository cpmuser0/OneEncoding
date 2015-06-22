=comment

    EDINET からの金融費用データ収集

    > jperl financial_expenses_collect.pl -M CODE [ { -Y yyyy | -H hh  } ]

    -M CODE1,CODE2,...
        nnnn    個別銘柄
        G31     その他金融業（東証33業種コード=31）の全銘柄および 8473 

    -Y yyyy
        yyyy 年の有報を対象とする。

    -H hh
        平成 hh 年の有報を対象とする。

    -R CODE
        （-M G31 のとき、）CODE から再開。

    -P
        PDFを保存する。

    -X
        一覧ページで IE を終了しないで停止する。

    Copyright (C) 2011-2014 MTEC. All rights reserved.

=cut
BEGIN {
    $ENV{MUS_DEBUG} = 1;
    $ENV{MUS_LOG_TRUNCATE} = 1;
}

#-------------------------------------------------------------------------------
#   1.0 使用モジュール宣言等
#-------------------------------------------------------------------------------
require 5.18.1;

our $VERSION = 0.03;

use strict;
use Data::Dumper;
use Encode qw( encode decode from_to );
use Getopt::Std;
use Win32::OLE;
use Win32::IEAutomation;
use Win32::GuiTest qw( FindWindowLike GetWindowText SetForegroundWindow SendKeys PushButton );
use lib './win32_lib';

use DBI;
use DownloadDialogResponder;
use MDL::Date qw( $DATE $TIME );
use MUS::StdLog;
use RunBackGround;
use IEAutomationFix;

my $H_00 = 1988;

#-------------------------------------------------------------------------------
#   2.0 対象銘柄コードの把握
#-------------------------------------------------------------------------------
print "$TIME ARGV=@ARGV\n";

our ( $opt_M, $opt_X, $opt_Y, $opt_H, $opt_R, $opt_P );

getopts( "M:XY:H:R:P" ) or die;

$opt_M ||= "G31";

$opt_Y and $opt_H and die "-Y yyyy と -H hh は同時に指定できません。";

if ( $opt_Y )
{
    $opt_Y =~ /^\d{4}$/ or die;
}
else
{
    $opt_Y = substr( $DATE, 0, 4 );

}

if ( $opt_H )
{
    $opt_H =~ /^\d{1,2}$/ or die;
    $opt_Y = $H_00 + $opt_H;
}
else
{
    $opt_H = $opt_Y - $H_00;
}

$opt_Y >= 2005 or die;

my $base_ym = MDL::Date->new( $opt_Y . "06" );
$DATE =~ /^(\d{6})/ or die;

my $curr_ym = MDL::Date->new($1) - 1;

my $code_ym = $curr_ym < $base_ym ? $curr_ym : $base_ym ;
my $base_date = $opt_Y . "/06/29";

my $code_list;
if ( $opt_M eq "G31" )
{
    print "$code_ym 時点のその他金融業上場銘柄と非上場銘柄のコードを把握しています。\n";

    my $dbh = DBI->connect( "dbi:ODBC:DSN=MTC1", undef, undef,
                            {
                                PrintError => 1,
                                RaiseError => 1,
                                # AutoCommit => 1,
                            } );

    # 東証33業種=31（その他金融業）の、上場銘柄および非上場銘柄
    # ただし、8473 ＳＢＩホールディングスは業種 29 （証券）
    my $code_array = $dbh->selectall_arrayref( <<SQL ) or die;

    select 銘柄コード from stock_db..株式月次時価
    where 基準年月=$code_ym and ( 東証３３業種コード=31 or 銘柄コード in ( 8473 ) )

    union

    select 銘柄コード from stock_ope_db..日経会社コード変換_非上場
        where 銘柄コード in (
            select convert(int, substring(issrcode,2,4) ) from bond_db..category_alter
            where date_from <= '$base_date' and '$base_date' < date_to and category_no=31
            )

    order by 銘柄コード

SQL

    $code_list = join( ",",  map{ $_->[0] } @$code_array );
}
else
{
    $code_list = $opt_M;
}

# print "code_list=$code_list\n";

#-------------------------------------------------------------------------------
#   3.0 EDINETコードへの変換
#-------------------------------------------------------------------------------
my $edinet_code_array;
{
    my $dbh = DBI->connect( "dbi:ODBC:DSN=DEV1", undef, undef,
                            {
                                PrintError => 1,
                                RaiseError => 1,
                                # AutoCommit => 1,
                            } );

    $edinet_code_array = $dbh->selectall_arrayref( <<SQL ) or die;
        select EDINET_CODE, 銘柄コード, 会社名 from active_db..会社コード対応表_old2
        where 銘柄コード in ( $code_list )
        order by 銘柄コード
SQL

}

#-------------------------------------------------------------------------------
#   4.0 EDINET 書類検索ページの表示
#-------------------------------------------------------------------------------
my $ie = Win32::IEAutomation->new( visible => 1, silent => 1 );
Win32::OLE->Option( Warn => 3 );

open my $proof, "> interest_expenses_proof.csv" or die $!;
select $proof; $| = 1;
select STDOUT;

GOTO_TOP:
{
    print "$TIME GOTO_TOP\n";

    # $ie->gotoURL( "http://disclosure.edinet-fsa.go.jp/EKW0EZ0001.html?lgKbn=2&dflg=0&iflg=0" );
    $ie->gotoURL( "https://disclosure.edinet-fsa.go.jp/E01EW/BLMainController.jsp?"
                    . "uji.bean=ee.bean.parent.EECommonSearchBean"
                    . "&uji.verb=W0EZA230CXP001007BLogic"
                    . "&TID=W1E63010&PID=currentPage"
                    . "&SESSIONKEY=&lgKbn=2&dflg=0&iflg=0" );

    $ie->WaitforDone;

    my $title = $ie->Title;
    print "Title=$title\n";

    unless ( $title =~ /EDINET/ )
    {
        sleep 1;
        redo GOTO_TOP;
    }
}


#-------------------------------------------------------------------------------
#   5.0 メイン制御 － 報告書一覧ページの走査
#-------------------------------------------------------------------------------
my $done_code;
my $current_code_index = 0;
my $code_input_retry;
my $popup_ie;
my @proof_item;

GET_PAGE_LINKS:
{
    my $code_tuple = $edinet_code_array->[ $current_code_index ];
    last GET_PAGE_LINKS unless $code_tuple;

    my ( $edinetcode, $code, $corp_name ) = @$code_tuple;

    if ( $opt_R and $code < $opt_R )
    {
        ++$current_code_index;
        redo GET_PAGE_LINKS;
    }

    undef @proof_item;

    $proof_item[ 0 ] = $current_code_index + 1;
    $proof_item[ 1 ] = $code;
    $proof_item[ 2 ] = $edinetcode;
    $proof_item[ 3 ] = $corp_name;

    print "\n$TIME Doing ---------------------- ( $edinetcode, $code )\n";

    if ( 0 )
    {
        open my $dump, "> TOP.htm" or die;
        my $content = $ie->Content;
        print $dump $content;
        close $dump;
    }

    {
        # デフォルトが「過去１年」であるため、変更する。
        my $list = $ie->getSelectList( "name:", "pfs" );
        $list->SelectItem( "全期間" );
    }

    # EDINETコードを入力して検索ボタンを押す。
    {
        $ie->getTextBox("id:", "mul_t")->SetValue( $edinetcode );

        $ie->getButton( "id:", "sch")->Click;
    }

    $ie->WaitforDone;

    if ( 0 )
    {
        # 一覧表のダンプ
        open my $dump, "> LIST.htm" or die;
        my $content = $ie->Content;
        print $dump $content;
        close $dump;
    }

    my $retry;
    LIST_PAGE:
    {

        if ( $opt_P )
        {

            # my @tables = $ie->getAllTables;
            my @tables = GetAllTables( $ie );

            my $found;
            foreach my $table ( @tables )
            {
                my @rows = $table->rows;
                foreach my $row ( @rows )
                {
                    my @cells = $row->cells;
                    next unless @cells > 1;
                    my $cell = $cells[1];
                    my $text = $cell->cellText;
                    print "DEBUG: $text\n";
                    next unless $text =~/(有価証券)報告書.+第(\d+)期.+平成(\d+)年(\d+)月(\d+)日.+平成(\d+)年(\d+)月(\d+)日/;
                    next if $text =~ /訂正/;

                    print "DEBUG: $1 $2 $3-$4-$5 $6-$7-$8\n";

                    my $mm = $7;
                    my $settle_yy = get_settle_yy( $3, $4, $6, $7 );
                    if ( $settle_yy == $opt_H )
                    {
                        my $pdf_cell = $cells[5];
                        $pdf_cell->{cell}->children(0)->children(0)->click;
                        $ie->WaitforDone;
                        last;
                    }

                }
            }
            exit;

        }

        my $found;
        my @links = $ie->getAllLinks;
        foreach my $link ( @links )
        {
            my $text = $link->linkText;
            # print "DEBUG: $text\n";
            next unless $text =~/(有価証券)報告書.+第(\d+)期.+平成(\d+)年(\d+)月(\d+)日.+平成(\d+)年(\d+)月(\d+)日/;
            next if $text =~ /訂正/;

            print "DEBUG: $1 $2 $3-$4-$5 $6-$7-$8\n";

            my $mm = $7;
            my $settle_yy = get_settle_yy( $3, $4, $6, $7 );
            if ( $settle_yy == $opt_H )
            {
                print "$text\n";
                exit if $opt_X;

                my $ym = sprintf "%d%02d", $opt_Y, $mm;
                $proof_item[ 4 ] = "$code-$ym-Y.pdf";

                # Win32::OLE-> WithEvents( $agent, \&EventHandler, 'DWebBrowserEvents2' );
                $found = 1;
                sleep 1;

=comment
                my $row = $link->{element}->parentNode->parentNode;
                my $pdf_link = $row->children(5)->children(0)->children(0);
                print "Click ", $pdf_link->{outerText}, "\n";
                $pdf_link->click;
                $ie->WaitforDone;

                my $popup = GetPopupWindow( "はじめに", 1 );
                my $agent = $popup->getAgent;

                # print join( "\n", sort keys %{ $popup_ie } ), "\n";
                print "DEBUG: href=", $agent->Document->href, "\n";

                exit;

=cut

                $link->Click;
                last;
            }
        }

        if ( $found )
        {
            $ie->WaitforDone;

            my $ret = ParsePopup();
            unless ( $ret )
            {
                ++$retry;
                if ( $retry < 3 )
                {
                    sleep 1;
                    redo LIST_PAGE;
                }
            }

            ++$current_code_index;
        }
        else
        {
            NEXT_LINK:
            {
                # my @links = $ie->getAllLinks;

                foreach my $link ( @links )
                {
                    my $url = $link->linkUrl;
                    if ( $url =~ /EEW1E62032_NEXT/ )    # 次へ
                    {
                        print "$url\n";
                        $link->Click;
                        $ie->WaitforDone;
                        redo LIST_PAGE;
                    }
                }
            }
            ++$current_code_index;
        }

        print $proof join( ",", @proof_item ), "\n";

        print "$TIME Done ----------------------- ( $edinetcode, $code )\n";
        $done_code = $code;

        redo GET_PAGE_LINKS;

=comment
        foreach my $link ( @links )
        {
            my $text = $link->linkText;
            if ( $text =~ /提出者検索/ )    # 提出者検索
            {
                print "$text\n";
                $link->Click;
                $ie->WaitforDone;
                redo GET_PAGE_LINKS;
            }
        }
=cut

    }

}

#-------------------------------------------------------------------------------
#   6.0 後処理
#-------------------------------------------------------------------------------

$ie->closeIE;

close $proof;

#-------------------------------------------------------------------------------
#   *.1 ログ
#-------------------------------------------------------------------------------
sub print_log
{
    print @_;
    1;
}

#-------------------------------------------------------------------------------
#   *.2 変則決算でない場合の年度を取得する
#-------------------------------------------------------------------------------
sub get_settle_yy
{
    my ( $yy1, $mm1, $yy2, $mm2 ) = @_;
    print "DEBUG: ( $yy1, $mm1, $yy2, $mm2 )\n";

    my $ym1 = MDL::Date->new( sprintf( "%d%02d", $H_00 + $yy1, $mm1  ) );
    my $ym2 = MDL::Date->new( sprintf( "%d%02d", $H_00 + $yy2, $mm2  ) );

    my $months = $ym2 - $ym1 + 1;
    $ym2 = $ym1 + 11 unless $months == 12;
    my $yy = substr( $ym2, 0, 4 ) - $H_00;

    print "DEBUG: settle_yy=$yy\n";

    return $yy;
}

#-------------------------------------------------------------------------------
#   5.1 ポップアップウィンドウの把握
#-------------------------------------------------------------------------------
sub GetPopupWindow
{
    my ( $what, $skip_frame_check ) = @_;

    my $counter;
    while($counter <= 2 ){
        my $shApp = Win32::OLE->new("Shell.Application") || die "Could not start Shell.Application\n";
        # print "DEBUG: shApp=$shApp\n";
        my $windows = $shApp->Windows;
        my $win_count = $windows->count;
        # print "DEBUG: GetPopupWindow [$counter] windows=$windows, win_count=$win_count\n";
        for (my $n = 0; $n < $win_count; $n++)
        {
            my $retry;
            CHECK_WINDOW:
            {
                print "DEBUG($what): Window [$n]\n";
                my $window = eval{ $windows->Item($n+1) };
                unless ( $window )
                {
                    print "Get window failed.\n";
                    sleep 1;
                    ++$retry;
                    if ( $retry < 3 )
                    {
                        redo CHECK_WINDOW;
                    }
                    return undef;
                }

                next unless %{ $window->Document };

                while ( $window->Busy || $window->Document->ReadyState ne "complete" )
                {
                    sleep 1;
                }

                my $title = $window->document->title if $window;
                print "DEBUG: [$n] title=$title\n";

                unless ( $skip_frame_check )
                {
                    my $frames = $window->Document->Frames;
                    next unless $frames;

                    # Frames がなければスキップ
                    my $nf = $frames->Length;
                    # print "DEBUG: nf=$nf\n";
                    next unless $nf;
                }

                if ( $title eq $what )
                {

                    print "DEBUG: Popup caught at [$n] with title=$title\n";

                    my %popup = %{$ie};
                    my $popupref = \%popup;
                    $popupref->{agent} = $window;
                    bless $popupref, "Win32::IEAutomation";
                    $popupref->WaitforDone;
                    return $popupref;
                }
                else
                {
=comment
                    my $title_temp = decode( "cp932", $title );
                    print "DEBUG: title_temp=$title_temp\n";
                    if ( $title_temp =~ /サーバーが見つかりません/ )
                    {
                        $window->Quit;
                    }
=cut
                }
            }
        }
        sleep 1;
        $counter++
    }

    print "WARNING: No popup window is present with your specified title: $what\n";
    undef;
}

#-------------------------------------------------------------------------------
#   5.1.1 ポップアップされた文書の解析
#-------------------------------------------------------------------------------

my $document_type_is_all_in_one;
my $start_object_no;
my $financial_expenses;
my $interest_expenses;
my $money_cost;

my @PL_html;
my @Remark_html;

sub ParsePopup
{
    undef @PL_html;
    undef @Remark_html;

    # my $popup = $ie->getPopupWindow("EDINET");
    my $popup = GetPopupWindow("EDINET");
    # my $popup = $ie->getPopupWindow("EDINET - Windows Internet Explorer");
    return undef unless $popup;

    my $popup_ie = $popup->getAgent;

    my $any_way_parsed;

    my $nf = $popup_ie->Document->Frames->Length;

    for ( my $f = 0; $f < $nf; ++$f )
    {

        my $frame = $popup_ie->Document->Frames( $f );
        # print "Frame[$f]: ", $frame->Document->Body->innerHTML ,"\n";

        my $nf_children = $frame->Document->Frames->Length;

        print "DEBUG: Frame[$f] $nf_children\n";

        next unless $nf_children;

        my $consolidated_report_exists;
        my $remark_no;
        my $consolidated_PL_link;
        my $consolidated_remark_link;
        my $nonconsolidated_PL_link;
        my $nonconsolidated_remark_link;

        my $click;
        {
            my $inner_frame = $frame->Document->Frames( 1 );
          PARSE1: {

            my $nfi = $inner_frame->Document->All->Length;

            print "DEBUG: FrameChild[1] $nfi\n";

            my $retry = 0;
            for ( my $i = 0; $i < $nfi; ++$i )
            {
                my $obj = eval { $inner_frame->Document->All( $i ) };
                redo PARSE1 unless $obj;

                my $tagname = eval{ $obj->tagName };
                if ( $retry < 1 and $@ )
                {
                    print "redo after $@\n";
                    sleep 1;
                    ++$retry;
                    redo;
                }

                next unless $tagname =~ /^A$/i;     # リンクでないエレメントはスキップする。
                                                    # <P> <A href=...> ○○ </A> </P> などの場合に注意。

                my $text = $obj->innerText;
                my $href = $obj->href;

                # print "DEBUG: [$i] $text\n";
                # print "DEBUG: [$i] $href\n";

                if ( $text =~ /連結財務諸表等/ )
                {
                    $consolidated_report_exists = 1;
                }
                elsif ( $text =~ /連結損益(及び包括利益)?計算書/ )
                {
                    print "DEBUG: [$i] 【連結】 $text,", $obj->tagName, "\n";
                    $consolidated_PL_link = $obj;           # 上書きにより、最終的には、最後のリンクを把握する。
                    $proof_item[5] = "○";
                }
                elsif ( $text =~ /(?<!連結)損益計算書/ )
                {
                    print "DEBUG: [$i] 【単独】 $text,", $obj->tagName, "\n";
                    $nonconsolidated_PL_link = $obj;        # 上書きにより、最終的には、最後のリンクを把握する。
                    $proof_item[13] = "○";
                }
                elsif ( $text =~ /注記事項|連結財務諸表注記/ )
                {
                    if ( $nonconsolidated_PL_link )
                    {
                        $nonconsolidated_remark_link = $obj;
                    }
                    else
                    {
                        $consolidated_remark_link = $obj;
                    }
                }
                $retry = 0;
            }
          } # PARSE1
        }

        $financial_expenses = undef;
        $interest_expenses = undef;
        $money_cost = undef;

        $document_type_is_all_in_one = 0;
        $start_object_no = 0;

        my $n;
        my $i_base;

        $n = 1;

        if ( $consolidated_PL_link )
        {
            $i_base = 6 + ($n - 1) * 8;
            ParsePL( $frame, $consolidated_PL_link, $n, $popup, $i_base );
            $any_way_parsed = 1;
        }

        if ( $consolidated_remark_link )
        {
            $i_base = 9 + ($n - 1) * 8;
            ParseRemark( $frame, $consolidated_remark_link, $n, $money_cost, $popup, $i_base );
            $any_way_parsed = 1;
        }

        $n = 2;

        if ( $nonconsolidated_PL_link )
        {
            $i_base = 6 + ($n - 1) * 8;
            ParsePL( $frame, $nonconsolidated_PL_link, $n, $popup, $i_base );
            $any_way_parsed = 1;
        }

        if ( $nonconsolidated_remark_link )
        {
            $i_base = 9 + ($n - 1) * 8;
            ParseRemark( $frame, $nonconsolidated_remark_link, $n, $money_cost, $popup, $i_base );
            $any_way_parsed = 1;
        }

        print "\t金融費用=$financial_expenses, 支払利息=$interest_expenses ( 資金原価=$money_cost )\n";

        last;
    }

    $popup->closeIE;

    # タイミングにより、リンク情報が取得されず、
    # ParsePL、ParseRemark のいずれも実行しない状況がありうるので、
    # その状況識別のための情報を返す。

    $any_way_parsed;
}

#-------------------------------------------------------------------------------
#   5.1.1.1 損益計算書の解析
#-------------------------------------------------------------------------------
sub ParsePL
{
    my ( $frame, $link, $n, $popup, $i_base ) = @_;

    print "DEBUG: ParsePL -----------------------------------------------------\n";
    # print "DEBUG: link=", $link->innerText ,", ", $link->linkText, "\n";
    print "DEBUG: (1) start_object_no=$start_object_no\n";
    print "DEBUG: link=", $link->innerText, "\n";

    $link->Click;
    $popup->WaitforDone;
    # $popup->WaitforDocumentComplete;

    # exit;

    my $popup_ie = $popup->getAgent;

    my $num_frames = $frame->Document->Frames->Length;
    print "DEBUG: num_frames=$num_frames\n";

    my $inner_frame = $frame->Document->Frames( 2 );
    my $unit;
    my @financial_expenses;
    my @interest_expenses;
    my @money_cost;

  PARSE2: {

    my $content = $inner_frame->Document->DocumentElement->{outerHTML};
    if ( 1 )
    {
        open my $dump, "> PL_$n.htm" or die;
        print $dump $content;
        close $dump;
    }

    $PL_html[$n-1] = $content;
    if ( $n == 2 )
    {
        $start_object_no = 0 if $PL_html[0] ne $PL_html[1];
    }
    print "DEBUG: (2) start_object_no=$start_object_no\n";

    my $nfi = $inner_frame->Document->All->Length;

    print "DEBUG: nfi=$nfi\n";

    # print "FrameChild[2]: $nfi\n";

    my $operating_expenses;
    my $nonoperating_expenses;
    my $financial_expenses_parent_exists;

    my $i = $start_object_no;
    for ( ; $i < $nfi; ++$i )
    {
        my $obj = $inner_frame->Document->All( $i );
        redo PARSE2 unless $obj;

        my $tagname = $obj->tagName;

        # printf "[%d] %s %s\n", $i, $tagname, $obj->innerText if $tagname =~ /^TR/;

        if ( $tagname =~ /^TITLE$/i )
        {
            my $text = $obj->innerText;
            print "DEBUG: [$i] TITLE $text\n";
            $document_type_is_all_in_one = 1 if $text =~ /有価証券報告書/;
        }
        elsif ( $tagname =~ /^CAPTION$/i )
        {
            # 金額単位を把握する。
            my $text = $obj->innerText;
            print "DEBUG: [$i] CAPTION $text\n";
            if ( $text =~ / (?:\(|（) 単位：(.+)円 (?:\)|）)/x )
            {
                $unit = $1;
                print "DEBUG: [$i] CAPTION $text, $unit\n";
            }
        }
        elsif ( $tagname =~ /^TR$/i )
        {
            my $text = $obj->innerText;

            # print "DEBUG: [$i] TR $text\n";

            if ( $text =~ / ( 営業 | 経常 ) 費用 /x )
            {
                # 8570 イオンフィナンシャルサービス 201403 では「経常費用」
                $operating_expenses     = 1;
            }
            elsif ( $text =~ /営業外費用/
                    or $operating_expenses and $text =~ /その他の金融収益・費用/ )
            {
                $nonoperating_expenses  = 1;
                $operating_expenses     = undef;
            }
            elsif ( $text =~ / (?<!その他の) ( 金融費用 | 資金調達費用 ) /x )
            {
                my $item_name = $1;     # ( 金融費用 | 資金調達費用 )
                print "DEBUG: $text\n";
                if ( !$financial_expenses_parent_exists or $text =~ /金融費用(?:\S{2})?計/ )
                {
                    # 親項目がある場合には、合計のみを見る。

                    @financial_expenses = GetAmountsFromTR( $item_name, $obj, $unit );

                    # 値が何も取得できないときは、「金融費用」の親項目とみなす。
                    $financial_expenses_parent_exists = 1 unless @financial_expenses;

                    if ( $text =~ /金融費用(?:\S{2})?計/ and @interest_expenses )
                    {
                        # 8461 ホンダファイナンス の場合など、「金融費用合計」に含めれており、
                        # 重複カウントを避けるため、クリアする。
                        # 8515 アイフル の場合は、「金融費用計」になっている。
                        undef @interest_expenses;
                    }
                }
            }
            elsif ( $text =~ /資金原価/ )
            {
                @money_cost = GetAmountsFromTR( "資金原価", $obj, $unit );
                print "DEBUG: 資金原価=@money_cost\n";
            }
            elsif ( $text =~ /支払利息/
                    or $nonoperating_expenses and $text =~ /その他の金融費用/
                    )
            {
                print "DEBUG: [$i] $tagname $text\n";
                if ( $operating_expenses and !@financial_expenses )
                {
                    if ( !$financial_expenses_parent_exists )
                    {
                        @financial_expenses = GetAmountsFromTR( "支払利息", $obj, $unit );
                        print "DEBUG: 支払利息(1) financial_expenses=@financial_expenses\n";
                    }
                }
                else
                {
                    @interest_expenses = GetAmountsFromTR( "支払利息", $obj, $unit );
                    print "DEBUG: 支払利息(2) interest_expenses=@interest_expenses\n";
                }
            }
            elsif ( $text =~ /百万円/ )
            {
                $unit ||= "百万";
            }
            elsif ( $text =~ /千円/ )
            {
                $unit ||= "千";
            }
        }
        elsif ( $tagname =~ /^H\d$/i )
        {
            if ( $obj->innerText =~ /キャッシュ \S* フロー計算書/x )
            {
                print "DEBUG: ", $obj->innerText, "; の支払利息は見ない。\n";
                last;
            }

            if ( $document_type_is_all_in_one
                    and $obj->innerText =~ /【注記事項】|連結財務諸表注記|その他/ )
            {
                print "DEBUG: [$i] encountered ", $obj->innerText, "\n";
                last;
            }
        }

        if ( @financial_expenses and @interest_expenses )
        {
            print "DEBUG: [$i] 金融費用および支払利息の取得完了\n";
            last;
        }
    }

    $start_object_no = $document_type_is_all_in_one ?  $i :  0;

  } # PARSE2

    my $cn = $n == 1 ? "連結" : "単独";
    print_log( "\t$cn-PLから取得: 金融費用=$financial_expenses[-1], 支払利息=$interest_expenses[-1], 単位=$unit\n" );

    my ( $f_ex, $i_ex, $m_c )= ( $financial_expenses[-1], $interest_expenses[-1], $money_cost[-1] );

    $proof_item[ $i_base + 0 ] = $f_ex;     # 金融費用
    $proof_item[ $i_base + 1 ] = $m_c;      # 資金原価
    $proof_item[ $i_base + 2 ] = $i_ex;     # 営業外費用（支払利息）

    $financial_expenses = $f_ex unless defined $financial_expenses;
    $interest_expenses  = $i_ex unless defined $interest_expenses;

    # last if defined $financial_expenses;
        # 金融費用があれば終了。
        # このとき、支払利息もあれば認識済み。
        # ただし、連結の金融費用があり、連結の支払利息がなｲ場合、
        # 単独の支払利息があっても無視。

    $money_cost     = $m_c unless defined $money_cost;
}

#-------------------------------------------------------------------------------
#   5.1.1.2 注記事項の解析
#-------------------------------------------------------------------------------
sub ParseRemark
{
    my ( $frame, $link, $n, $money_cost, $popup, $i_base ) = @_;

    print "DEBUG: ParseRemark --------------------------------------------------\n";
    print "DEBUG: (1) start_object_no=$start_object_no\n";
    print "DEBUG: link=", $link->innerText, "\n";

    $link->Click;
    $popup->WaitforDone;

    my $popup_ie = $popup->getAgent;

    my $num_frames = $frame->Document->Frames->Length;
    print "DEBUG: num_frames=$num_frames\n";

    my $inner_frame = $frame->Document->Frames( 2 );
    my @financial_expenses_from_table;
    my @financial_expenses;
    my @interest_expenses;

    my $retry;
    my $next_page_count;
  PARSE2: {

    my $content = $inner_frame->Document->DocumentElement->{outerHTML};
    if ( 1 )
    {
        open my $dump, "> Remark_$n.htm" or die;
        print $dump $content;
        close $dump;
    }

    $Remark_html[$n-1] = $content;
    if ( $n == 1 )
    {
        $start_object_no = 0 if $Remark_html[0] ne $PL_html[0];
    }
    else
    {
        $start_object_no = 0 if $Remark_html[1] ne $PL_html[1];
    }
    print "DEBUG: (2) start_object_no=$start_object_no\n";

    my $distance_limit = 24;

    my $nfi = $inner_frame->Document->All->Length;

    my $money_cost_parent_row;
    my $tr_count_from_money_cost_parent;
    my $financial_expenses_paragraph_no;

    print "DEBUG: nfi=$nfi\n";

    my $i = $start_object_no;
    for ( ; $i < $nfi; ++$i )
    {
        print "DEBUG: $TIME i=$i\n" if $i % 1000 == 0;
        my $obj = $inner_frame->Document->All( $i );
        unless ( $obj )
        {
            ++$retry;
            redo PARSE2 if $retry < 3;
            print "DEBUG: $i-th obj failed.\n";
            next;
        }

        my $tagname = $obj->tagName;
        # print "DEBUG: [$i] tagname=$tagname, ", $obj->innerText, "\n" if $n == 2 and $tagname =~ /^P$/i;

        if ( $tagname =~ /^P$/i )
        {
            if ( $obj->innerText =~ /金融費用/ )
            {
                $financial_expenses_paragraph_no =$i;
            }
        }

        if ( $tagname =~ /^A$/i and $obj->innerText =~ /次へ/ and !@financial_expenses_from_table )
        {
            ++$next_page_count;
            print "DEBUG: ", $obj->innerText, " ($next_page_count) Click\n";
            $obj->Click;
            $popup->WaitforDone;
            redo PARSE2;
        }

        if ( $tagname =~ /^TR$/i )
        {
            ++$tr_count_from_money_cost_parent if $money_cost_parent_row;

            if ( !@financial_expenses_from_table )
            {
                my $text = $obj->innerText;
                if ( $text =~ /金融費用\s*([,\d]+)\s*(百万|千)円/ )
                {
                    my ( $value, $unit ) = ( $1, $2 );

                    my $num_c_tr = CountNumChildrenWithTag( $obj, "TR" );
                    # print "DEBUG: num_c_tr=$num_c_tr\n";
                    next if $num_c_tr > 0;  # 外側の TABLE で認識した場合はスキップする。

                    # print "DEBUG: $text\n";
                    push @financial_expenses, [ make_it_numeric( $value, $unit ) ];
                    last if @financial_expenses == 2;
                }
                elsif ( $text =~ /資金原価.*内訳/s )
                {
                    print "DEBUG: 資金原価.*内訳 (1) [$i] $text\n";
                    $money_cost_parent_row = $i;
                    $tr_count_from_money_cost_parent = 0;
                }
                elsif ( !@financial_expenses
                        and ( !$money_cost or $money_cost_parent_row )
                            # PL に資金原資があったのならば、資金原価.*内訳を見た後に支払利息を見る。
                            # ただし、<TABLE>タブがあれば、GetAmountFromTABLE 側で把握するので、
                            # ここのマッチには来ない。
                        and $text =~ / (?<!\S{2}) 支払利息 (?:\D{2})? \s* ([,\d]+) \s* (百万|千)円 /x )
                {
                    my ( $value, $unit ) = ( $1, $2 );
                    print "DEBUG: 支払利息 ( $value, $unit )\n";

                    my $num_c_tr = CountNumChildrenWithTag( $obj, "TR" );
                    # print "DEBUG: num_c_tr=$num_c_tr\n";
                    next if $num_c_tr > 0;  # 外側の TABLE で認識した場合はスキップする

                    if ( $money_cost_parent_row and $tr_count_from_money_cost_parent > 6  )
                    {
                        print_log( "WARNING: 「資金原価...」の行から離れすぎています。tr_count=$tr_count_from_money_cost_parent\n" );
                        last;
                    }

                    if ( $financial_expenses_paragraph_no )
                    {
                        my $j = $i - $financial_expenses_paragraph_no;
                        if ( $j > 3 )
                        {
                            print_log( "WARNING: 「金融費用...」の段落から離れすぎています。j=$j\n" );
                            last;
                        }
                    }

                    print "DEBUG: [$i] $text; ( $value, $unit ); $financial_expenses_paragraph_no\n";

                    print "DEBUG: ", join(",", $i, $obj->tagName, $text ), "\n";
                    push @interest_expenses, [ make_it_numeric( $value, $unit ) ];
                    last if @interest_expenses == 2;
                }
            }
        }
        elsif ( !$money_cost_parent_row and $tagname =~ /^P$/i )
        {
            my $text = $obj->innerText;
            if ( $text =~ /資金原価.*内訳/s )
            {
                print "DEBUG: 資金原価.*内訳 (2) [$i] $text\n";
                $money_cost_parent_row = $i;
                $tr_count_from_money_cost_parent = 0;
                $distance_limit = 4;
            }
        }
        elsif ( $money_cost_parent_row and $tagname =~ /^TABLE$/i and $tr_count_from_money_cost_parent < $distance_limit )
        {
            print "DEBUG: tr_count_from_money_cost_parent=$tr_count_from_money_cost_parent\n";
            my $amount = GetAmountFromTABLE( $obj );
            push @financial_expenses_from_table, $amount if defined $amount;
            last if @financial_expenses_from_table == 2;
        }
        elsif ( $tagname =~ /^H\d/ )
        {
            if ( $document_type_is_all_in_one
                    and $obj->innerText =~ /損益計算書】/ )
            {
                print "DEBUG: [$i] encountered ", $obj->innerText, "\n";
                last;
            }
        }

    }

    $start_object_no = $document_type_is_all_in_one ?  $i :  0;

  } # PARSE2

    print "DEBUG: financial_expenses_from_table=@financial_expenses_from_table\n";
    print "DEBUG: financial_expenses=@financial_expenses\n";
    print "DEBUG: interest_expenses=@interest_expenses\n";

    my @target_value = @financial_expenses_from_table ? @financial_expenses_from_table :
                            ( @financial_expenses ? @financial_expenses : @interest_expenses );

    print_log( "\t注記から取得: 金融費用=$target_value[-1] （資金原価=$money_cost）\n" );

    if ( $target_value[-1] and $money_cost and $target_value[-1] < $money_cost  )
    {
        print_log( "WARNING: 金融費用 $target_value[-1] が 資金原価 $money_cost より小さい。\n" );
    }

    my ( $t, $r ) =  defined $target_value[-1] ? @{ $target_value[-1] } : ();

    unless ( defined $financial_expenses )
    {
        # 注記からの情報収集は、金融費用が未定の場合にのみ行う。

        my $f_ex = $t + $r if defined $t;
        my $i_base = 9 + ($n - 1) * 8;
        $proof_item[ $i_base + 0 ] = $t;        # 差引合計
        $proof_item[ $i_base + 1 ] = $r;        # 受取利息等
        $proof_item[ $i_base + 2 ] = $f_ex;     # 営業費用（支払利息等） ---- 中計

        $financial_expenses = $f_ex;
    }
}

#-------------------------------------------------------------------------------
#   5.1.1.*.1 TR エレメントからの金額取得
#-------------------------------------------------------------------------------
sub GetAmountsFromTR
{
    my ( $item_name_disp, $obj, $unit ) = @_;

    print "DEBUG: GetAmountsFromTR @_\n";

    my $nc = $obj->Children->Length;

    my @amount;
    my $item_name;
    for ( my $j = 0; $j < $nc; ++$j )
    {
        my $c = $obj->Children( $j );
        my $cell = $c->innerText;

        if ( $cell =~ s/    ^ \s* 
                            (?:\(|（)       # 半角または全角の左括弧
                            ( .+ )
                            (?:\)|）)       # 半角または全角の右括弧
                            \s* $ /$1/x )
        {
            # 8473 ＳＢＩホールディングスの 201303 の場合
            print "DEBUG: [$j] 両端の ( ) を削除\n";
        }
        print "DEBUG: [$j] $cell\n";

        if ( $cell =~ /([\d,]+) \s* $/x )     # 「※2 16,217」などの場合があるため、先頭のアンカー "^" は付けない。
        {
            my $value = $1;
            push @amount, make_it_numeric( $value, $unit );
        }
        elsif ( $cell =~ /^ \s* - \s* $/x )
        {
            push @amount, 0 if $item_name;  # 項目名の後ならば値を認識
        }
        elsif ( $cell =~ /^\s*$/ )
        {
            # push @amount, undef if $item_name;  # 項目名の後ならば値を認識
            # 8591 オリックスの場合など、金額らん以外を誤認する可能性がある。
        }
        else
        {
            $item_name = $cell;     # 空白以外
        }
    }

    undef @amount if "@amount" =~ /^\s*$/;

    @amount;
}

#-------------------------------------------------------------------------------
#   5.1.1.2.1 特定のタグを持つ子エレメントを数える
#-------------------------------------------------------------------------------
sub CountNumChildrenWithTag
{
    my ( $obj, $tag ) = @_;

    my $num = 0;

    my $nc = $obj->Children->Length;

    for ( my $i = 0; $i < $nc; ++$i )
    {
        my $c = $obj->Children( $i );
        ++$num if $c->tagName eq $tag;
        $num += CountNumChildrenWithTag( $c, $tag );
    }

    $num;
}


#-------------------------------------------------------------------------------
#   5.1.1.2.2 TABLE エレメントからの金額取得
#-------------------------------------------------------------------------------
sub GetAmountFromTABLE
{
    my ( $obj ) = @_;

    my $nc = $obj->Children->Length;

    my @interest_expenses;
    my @other_amount;
    my @total_amount;
    my @interest_imcome;

    for ( my $j = 0; $j < $nc; ++$j )
    {
        my $c = $obj->Children( $j );

        # print "DEBUG: c[$j] ", $c->tagName, "\n";

        my $ngc = $c->Children->Length;
        if ( $ngc )
        {

            my $unit;
            for ( my $k = 0; $k < $ngc; ++$k )
            {
                my $gc = $c->Children( $k );

                # print "DEBUG: gc[$k] ", $gc->tagName, "\n";
                my $unit_tr;
                if ( $gc->tagName =~ /TR/i )
                {
                    # 単位が次のセルに分離されている場合用に TR で把握しておく。
                    my $cell = $gc->innerText;
                    if ( $cell =~ /(百万|千)/ )
                    {
                        $unit_tr = $1;
                    }
                }

                my $nggc = $gc->Children->Length;
                next unless $nggc;

                my $cell_type;
                my $plus_minus_total_exists;

                for ( my $m = 0; $m < $nggc; ++$m )
                {
                    my $ggc = $gc->Children( $m );

                    # print "DEBUG: ggc[$m] ", $ggc->tagName, "\n";

                    my $cell = $ggc->innerText;
                    print "DEBUG: GetAmountFromTABLE [$j,$k,$m] ( $nggc ) $cell, cell_type=$cell_type\n";
                    $cell =~ s/\s+//g;
                    $cell =~ s/　//g;

                    if ( $m == 0 )
                    {
                        if ( $cell =~ /支払利息/ )
                        {
                            # 支払利息等の場合も含める
                            $cell_type = 1;
                        }
                        elsif ( $cell =~ /受取利息/ )
                        {
                            # 受取利息等の場合も含める
                            $cell_type = 2;
                        }
                        elsif ( $cell =~ /差引/ )
                        {
                            # 差引計,差引 のいずれかを想定。
                            $cell_type = 3;
                            $plus_minus_total_exists = 1;
                        }
                        elsif ( $cell =~ /計/ )
                        {
                            # 合計,計 のいずれかを想定。
                            $cell_type = 3 unless $plus_minus_total_exists;
                        }
                        else
                        {
                            $cell_type = 9;
                        }
                    }
                    else
                    {
                        if ( $cell =~ /([\d,]+)(百万|千)?(円)?\s*$/ )
                        {
                            $unit ||= $2;
                            $unit ||= $unit_tr;     # 単位が次のセルに分離されている場合
                            if ( $cell_type == 1 )
                            {
                                push @interest_expenses, make_it_numeric( $1, $unit );
                            }
                            elsif ( $cell_type == 2 )
                            {
                                push @interest_imcome, make_it_numeric( $1, $unit );
                            }
                            elsif ( $cell_type == 3 )
                            {
                                push @total_amount, make_it_numeric( $1, $unit );
                            }
                            elsif ( $cell_type == 9 )
                            {
                                push @other_amount, make_it_numeric( $1, $unit );
                            }
                        }
                    }
                }
            }
        }
        else
        {
            my $cell = $c->innerText;
            print_log( "WARNING: GetAmountFromTABLE [$j] $cell\n" ) unless $cell =~ /^\s*$/;
        }
    }

    print "DEBUG: GetAmountFromTABLE @total_amount, @interest_imcome\n";

    # 8793 ＮＥＣキャピタルソリューションの注記では、
    # その他の金額が実質ゼロであり、
    # 丸めによる数値の微細な不整合を避けるため、
    # その判断を行う。
    my $actual_other_amount = 0;
    for ( my $i = 0; $i < @other_amount; $i += 2 )
    {
        $actual_other_amount += $other_amount[$i+1];
    }

    if ( @total_amount == 1 and @interest_imcome == 1 )
    {
        if ( $actual_other_amount == 0 and  @interest_expenses == 1 )
        {
            # 8566 リコーリース の 201103 など
            # この場合、interest_expenses が中計の意味
            return [ $interest_expenses[0] - $interest_imcome[0], $interest_imcome[0] ];
        }
        else
        {
            return [ $total_amount[0], $interest_imcome[0] ];
        }
    }
    elsif ( @total_amount == 2 and @interest_imcome == 1 )
    {
        if ( abs( $total_amount[0] - $interest_imcome[0] - $total_amount[1] ) < 2 )
        {
            return [ $total_amount[0], $interest_imcome[0] ];
        }
    }
    elsif ( @total_amount == 2 and @interest_imcome == 2 )
    {
        if ( $actual_other_amount == 0 and  @interest_expenses == 2 )
        {
            # 8433 ＮＴＴファイナンス の 201203 など
            # この場合、interest_expenses が中計の意味
            return [ $interest_expenses[1] - $interest_imcome[1], $interest_imcome[1] ];
        }
        else
        {
            # 8593 三菱ＵＦＪリース の 201203 など
            return [ $total_amount[1], $interest_imcome[1] ];
        }
    }
    elsif ( @total_amount == 4 and @interest_imcome == 2 )
    {
        if ( abs( $total_amount[1] - $interest_imcome[1] - $total_amount[3] ) < 2 )
        {
            return [ $total_amount[3], $interest_imcome[1] ];
        }
        else
        {
            print "DEBUG: abs( $total_amount[1] - $interest_imcome[1] - $total_amount[3] ) >= 2\n";
        }
    }

    print_log( "WARNING: GetAmountFromTABLE 想定外 [ @total_amount ]; [ @interest_imcome ]\n" );
    return [];
}

#-------------------------------------------------------------------------------
#   *.1 数値化（カンマを削除し、百万円単位の値にする）
#-------------------------------------------------------------------------------
sub make_it_numeric
{
    my ( $value, $unit ) = @_;
    $value =~ s/,//g;
    if ( $unit eq "百万" )
    {
        # ok
    }
    elsif ( $unit eq "千" )
    {
        $value = sprintf "%.0f", $value / 1000;
    }
    else
    {
        die "予期しない単位 $unit";
    }
    $value;
}

__END__

