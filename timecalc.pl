#!/usr/bin/perl

# 時間計算機 timecalc： 時間を含む四則演算を行うCGI
#
# 2015-01-19 Yuki Naito (@meso_cacase)

use warnings ;
use strict ;

#- ▼ URIからパラメータを取得
(my $request_uri  = $ENV{'REQUEST_URI'} // '')
                  =~ s/\?.*// ;       # '?' 以降のQUERY_STRING部分を除去
(my $query_string = url_decode($request_uri) // '')
                  =~ s{^/timecalc/}{} ;
#- ▲ URIからパラメータを取得

#- ▼ QUERY_STRINGからパラメータを取得
my %query = get_query_parameters() ;  # HTTPリクエストからクエリを取得

$query_string =                       # 検索クエリ
	$query{'query'} //                # 1) QUERY_STRINGから
	$query_string   //                # 2) QUERY_STRING未指定 → URIから
	'' ;                              # 3) URI未指定 → 空欄
#- ▲ QUERY_STRINGからパラメータを取得

#- ▼ パラメータからURIを生成してリダイレクト
my $redirect_uri = '/' ;
$redirect_uri .= ($request_uri =~ m{^/timecalc/}) ? 'timecalc/' : '' ;
$redirect_uri .= url_encode($query_string) ;

if ($ENV{'HTTP_HOST'} and              # HTTP経由のリクエストで、かつ
	($request_uri ne $redirect_uri or  # 現在のURIと異なる場合にリダイレクト
	 $ENV{'QUERY_STRING'})
){
	redirect_page("http://$ENV{'HTTP_HOST'}$redirect_uri") ;
}
#- ▲ パラメータからURIを生成してリダイレクト

# $query_stringが空欄のときはトップページを表示
$query_string eq '' and print_html() ;

# ▼ 計算を実行
my $eq = $query_string ;
$eq =~ s/(?<=[\(\)\+\-\*\/])|(?=[\(\)\+\-\*\/])/ /g ;  # 演算子と括弧の前後にスペースを挿入
my @eq = split /\s+/, $eq ;

foreach (@eq){
	s{,}{}g ;  # コンマを無視
	s{^([\.\d]+):([\.\d]+)$}{($1+$2/60)}e ;  # 00:00 を時間(h)に変換
	s{^([\.\d]+):([\.\d]+):([\.\d]+)$}{($1 + $2/60 + $3/3600)}e ;  # 00:00:00 を時間(h)に変換
}

my $hrs = eval join(' ', @eq) or print_html('ERROR : へんな記号が含まれていませんか') ;
my $min = $hrs * 60 ;
my $sec = $hrs * 3600 ;

my $hh = int( sprintf("%.4f", $hrs) ) ;
my $mm = int( sprintf("%.4f", ($hrs - $hh)*60 ) ) ;
my $ss = int( sprintf("%.4f", ($hrs - $hh - $mm/60)*3600 ) ) ;
my $ms = int( sprintf("%.4f", ($hrs - $hh - $mm/60 - $ss/3600)*3600000 ) ) ;
my $hhmmss = sprintf("%02d:%02d:%02d.%03d", $hh, $mm, $ss, $ms) ;

$hrs = sprintf("%.3f", $hrs) ;
$min = sprintf("%.3f", $min) ;
$sec = sprintf("%.3f", $sec) ;
# ▲ 計算を実行

# ▼ HTMLを出力
print_html(
"<div id='result'>
= <input type=text readonly size=20 value='$hhmmss'><br>
= <input type=text readonly size=20 value='$hrs'>時間<br>
= <input type=text readonly size=20 value='$min'>分<br>
= <input type=text readonly size=20 value='$sec'>秒
</div>"
) ;
# ▲ HTMLを出力

exit ;

# ====================
sub get_query_parameters {  # CGIが受け取ったパラメータの処理
my $buffer = '' ;
if (defined $ENV{'REQUEST_METHOD'} and
	$ENV{'REQUEST_METHOD'} eq 'POST' and
	defined $ENV{'CONTENT_LENGTH'}
){
	eval 'read(STDIN, $buffer, $ENV{"CONTENT_LENGTH"})' or
	print_html('ERROR : get_query_parameters() : read failed') ;
} elsif (defined $ENV{'QUERY_STRING'}){
	$buffer = $ENV{'QUERY_STRING'} ;
}
length $buffer > 1000000 and print_html('ERROR : input too large') ;
my %query ;
my @query = split /&/, $buffer ;
foreach (@query){
	my ($name, $value) = split /=/ ;
	if (defined $name and defined $value){
		$value =~ tr/+/ / ;
		$value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack('C', hex($1))/eg ;
		$name  =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack('C', hex($1))/eg ;
		$query{$name} = $value ;
	}
}
return %query ;
} ;
# ====================
sub url_decode {  # URLデコード（ただしスペースは+でなく%20とする）
my $str = $_[0] or return '' ;
$str =~ s/%([0-9A-F]{2})/pack('C', hex($1))/ieg ;
return $str ;
} ;
# ====================
sub url_encode {  # URLエンコード（ただしスペースは+でなく%20とする）
my $str = $_[0] or return '' ;
# $str =~ tr/+/Z/ ;
$str =~ s/([^\w\-\.\,\_\~\(\)\:\/\+\*])/'%' . unpack('H2', $1)/eg ;
return $str ;
} ;
# ====================
sub redirect_page {  # リダイレクトする
my $uri = $_[0] // '' ;
print "Location: $uri\n\n" ;
exit ;
} ;
# ====================
sub escape_char {  # < > & ' " の5文字を実態参照に変換
my $string = $_[0] // '' ;
$string =~ s/\&/&amp;/g ;
$string =~ s/</&lt;/g ;
$string =~ s/>/&gt;/g ;
$string =~ s/\'/&#39;/g ;
$string =~ s/\"/&quot;/g ;
return $string ;
} ;
# ====================
sub print_html {  # HTMLを出力

#- ▼ メモ
# ・比較結果ページを出力（デフォルト）
# ・引数が ERROR で始まる場合はエラーページを出力
# ・引数がない場合はトップページを出力
#- ▲ メモ

my $html = $_[0] // '' ;

#- ▼ エラーページ：引数が ERROR で始まる場合
$html =~ s{^(ERROR.*)$}{<p><font color=red>$1</font></p>}s ;
#- ▲ エラーページ：引数が ERROR で始まる場合

#- ▼ トップページ：引数がない場合
(not $html) and $html =
"<div id='usage'>
<p>つかいかた：</p>

<ul>
	<li>(1:23:45.67+22:22+12.34)/3 のような計算が簡単にできます。
	<li>URLに数式を入れて計算することもできます：<br>
		<a href='http://altair.dbcls.jp/timecalc/(1:23:45.67+22:22+12.34)/3'>
		http://altair.dbcls.jp/timecalc/(1:23:45.67+22:22+12.34)/3</a>
	<li>使える記号：+, -, *, /, (, )
</ul>
</div>" ;
#- ▲ トップページ：引数がない場合

#- ▼ HTML出力
$query_string = escape_char($query_string) ;  # XSS対策

print "Content-type: text/html; charset=utf-8\n\n",

#-- ▽ +++++++++++++++++ HTML +++++++++++++++++++
"<!DOCTYPE HTML PUBLIC '-//W3C//DTD HTML 4.01 Transitional//EN'>
<html lang=ja>

<head>
<meta http-equiv='Content-Type' content='text/html; charset=utf-8'>
<meta http-equiv='Content-Style-Type' content='text/css'>
<meta name='author' content='Yuki Naito'>
<title>時間計算機</title>
<style type='text/css'>
<!--
	* { font-family:verdana,arial,helvetica,sans-serif }
	p,ul,textarea { font-size:10pt }
	a { color:#3366CC }
	.k { color:black; text-decoration:none }
-->
</style>
</head>

<body>

<div id='top' style='border-top:5px solid #00BBFF; padding-top:10px'>
<a class=k href='http://altair.dbcls.jp/timecalc/'>
	<font size=5>時間計算機</font>
</a>
</div>

<div id='form'>
<form name=timecalc method=GET action='.'>
<input type=text name=query size=70 value='$query_string'>
<input type=submit value=' 計算 '>
</form>
</div>

$html

</body>
</html>
" ;
#-- △ +++++++++++++++++ HTML +++++++++++++++++++
#- ▲ HTML出力

exit ;
} ;
# ====================
