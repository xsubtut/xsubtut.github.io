現状、本稿ははげしくかきかけです。フィードバックをおまちしております。

## はじめに

Perl で C の拡張がスラスラと書けたら……。C の拡張がスラスラ書けたら、ネイティブのバインディングもスラスラ書けるし、ホットスポットを C で最適化するなんてこともお手の物。書けたらいいけど、XS ってなんかむずかしそう……。

ちがうんです! 今までの XS の教え方がまちがっていたんです!この教材をつかえば、誰でも簡単に今すぐに XS を書けるようになるんです。Perl の C 拡張を書いて同僚や上司を アッー! と言わせちゃおう!

この教材では XS のややこしい機能をつかわずに、Perl の C 拡張を書く方法を伝授!初心者でもすぐに C 拡張が書けるようになるぞ!

### 前提知識

本稿では一般的な C の知識および Perl の知識を読者がもっていることを想定しています。XS の知識や Perl の内部構造に関する知識はもっていない前提ですので、万が一そういったものが要求されている!! と感じた場合には、github issues などで教えてください。

## XS とは

Perl の世界では、XS という言語をつかって C 拡張を記述します。これは基本的には C にたいするマクロ言語です。正規表現でがんばって置換しているだけなので、あまりかしこくはありません。かなりいろいろな機能があるのですが、いろいろできすぎて初心者にやさしくないので、本稿では、ごくごくシンプルな記法のみを紹介します。

XS は本当にいろいろできて便利なのですが、いざこったことをやろうとすると、基本的な方法にもどらざるをえない、というようなことも多発しますので、本稿ではただひたすらに基本的な方法を紹介しつづけます。

## 型を知る

Perl の内部データは構造体におさまっています。そのあたりを把握していきましょう。

継承関係にあるものは親にキャストが可能です。たとえば、AV* は SV* にキャストできます。



                 B::SV
                   |
      +------------+------------+------------+
      |            |            |            |
    B::PV        B::IV        B::NV        B::RV
        \         /           /
         \       /           /
          B::PVIV           /
               \           /
                \         /
                 \       /
                  B::PVNV
                     |
                     |
                  B::PVMG
                     |
         +-----+-----+-----+-----+
         |     |     |     |     |
       B::AV B::GV B::HV B::CV B::IO
               |           |
               |           |
            B::PVLV      B::FM

### SV

Perl のすべての値は SV から派生しています。SV は Scalar Value のことです。

### IV

SV has-a IV の関係です。SV 構造体の中に IV が格納されている、とおもってください。整数値がはいっています。

	IV iv = SvIV(sv);
	
とすることで、`SV*` を IV に変換できます。

	SV* sv = newSViv(iv);

とすることで、IV を `SV*` に変換できます。

### NV

SV has-a NV の関係です。SV 構造体の中に NV が格納されている、とおもってください。浮動小数点値がはいっています。

### AV

AV is-a SV の関係です。配列データがはいっています。SV にキャストしてつかうことができます。

### HV

HV is-a SV の関係です。ハッシュです。SV にキャストしてつかうことができます。

### RV

RV is-a SV の関係です。Reference Value の略です。

## リファレンスカウント

Perl5 におけるメモリの管理はリファレンスカウントという方式でおこなわれています。これはつまり、変数ごとに「この変数は○箇所から参照されているョ」というマークをつけておき、どこからも参照されなくなったらその部分のメモリを再利用するというだけの仕組みです。

リファレンスカウンタ方式のメモリ管理では、このリファレンスカウンターの操作を、拡張モジュールの作者が気をつけておこなわなければなりません。

一方で、メモリの増減などが予測しやすい、デバッグがしやすいというメリットもあります。

各 Perl API の、どのタイミングでリファレンスカウントが増減するのかを把握することが、拡張モジュールを書く上での第一歩だといえます。

### mortal な SV

参照カウントで一番問題になるのは、今自分がもっている参照カウントをどうやって手放すか、ということです。
今てばなしたら0になってしまってSVが開放されてしまうし、手放さなければメモリリーク。どうしたものか!

ということで、Perl5 の世界では「このスコープをぬけたらこれ開放しておいてね!」と Perl5 本体にいっておくことができるようになっています。この「あとで開放しておいてね!」といっておくことを「mortal 状態にする」といいます。

コードで、SV を mortal にするには、`sv_2mortal(sv)` とします。`sv_2mortal` の返り値は、引数にわたした `SV*` です。

`sv_2mortal` は、やたらめったらつかうところが多いので、XS の世界にはさまざまなショートカットが用意されています。たとえば `XPUSHs(sv_2mortal(sv))` を `mXPUSHs(sv)` などという風に省略して書けるのです。これは便利なのですが、おぼえることがふえてしまうので本稿ではこういった省略記法はふれないです。

(なお、iPhone/OSX のアプリケーションを開発していらっしゃる方なら autorelease みたいなものだと考えればわかりやすいです! っていうと最近はよかったのですが、最近は autorelease って時代遅れなかんじがするのでこの比喩ももはやつかえません。)

## なにはなくとも Hello, world!

前提知識の羅列が続く文章ほどダルいものもないので、実際のコードを見たい、とおもっている方も多かろう。まずは、もっともシンプルなケースを見ていこう。以下は、標準出力に "Hello, world!" という文字列を表示するだけの簡単なコードだ。

今回のコードは (TODO) で見ることができる。

### はじめての XS

以下が今回よむ XS コードの全貌である。XS で書かれたコードはなんとも珍妙な見た目をしているが、慣れてしまえばどうということはない。美人は三日で飽きるがブスは三日で慣れるというではないか。

	#define PERL_NO_GET_CONTEXT
	#include "EXTERN.h"
	#include "perl.h"
	#include "XSUB.h"
	
	#include "ppport.h"
	
	MODULE = Hello          PACKAGE = Hello
	
	void
	hello(...)
	PPCODE:
	{
	    PerlIO_printf(PerlIO_stdout(), "Hello, world!\n");
	    XSRETURN(0);
	}

まず最初に、引数の受取および返り値の返却においては、スタック構造がつかわれていることを意識してください。引数をスタックにつんだ状態で XS の関数(XSUB)はコールされます。返却値はスタックにつんでから return します。これを常に意識しながらすすむことが肝要です。

	#define PERL_NO_GET_CONTEXT
	#include "EXTERN.h"
	#include "perl.h"
	#include "XSUB.h"

の部分はヘッダファイルをよみこんでいるだけなので問題ないかとおもいます。`PERL_NO_GET_CONTEXT` は、指定すると効率がよくなる場合があるマクロなので、なんとなく指定しておけばよい。

	MODULE = Hello          PACKAGE = Hello

ここは、モジュールとパッケージの指定だ。一つのファイルに複数個書くことができる。この宣言以下の部分は、`PACKAGE=` で指定したパッケージにひもづくこととなる。

	void
	hello(...)
	PPCODE:

ここは、もうなんというか、そういうものだとおもってください!! ってかんじである。値を返そうが返すまいがとりあえず void を指定し、引数は可変長かのように指定し、PPCODE: という修飾子を指定することにより、おぼえることをすごくへらすことができるんです! そういうものなんです! なお、hello の部分が関数名となることはいうまでもない。

さていよいよ本文だ。`PerlIO_printf()` は printf 関数を XSUB の世界からコールするときにつかう API です。PerlIO を通しておこなってくれるのがポイントです。`PerlIO_stdout()` は `*STDOUT` に対して処理をおこなうよ、という意味ですね。あとの引数は通常の printf(1) とおなじです。

`XSRETURN(0)` では返り値の数を指定しています。今回は一個も返り値はないので `XSRETURN(0)` としています。

### XS モジュールのロード

XS モジュールは XSLoader というモジュールをつかってロードする。DynaLoader というモジュールでロードしてもよいのだが、原状では XSLoader をつかう方が主流なので、こちらをつかっておけば間違いはない。

使い方は簡単で、以下のようにすればよい。

	package Hello;
	our $VERSION="0.01";
	require XSLoader;
	XSLoader::load(__PACKAGE__, $VERSION);

これはもうテンプレだとおもってつかっていればよい。

なお、[Minilla](https://metacpan.org/module/Minilla) のようなスケルトンジェネレータをつかえば、このあたりのコードは自動生成されるので、通常は意識する必要はない。

## 引数を処理し、値を返す XS

Hello, world の例では引数の処理や値を返す処理がなかった。説明を簡略化するためにはぶいたのだが、実際のところ、引数もなく値もかえさない XS など通常は意味がないだろう。

そういうわけで、そういった処理をする XS を書いてみよう。

	MODULE = Sum            PACKAGE = Sum
	
	void
	sum(...)
	PPCODE:
	{
	    if (items != 2) {
	        croak("Invalid argument count: %d", items);
	    }
	    SV *a = ST(0);
	    SV *b = ST(1);
	
	    IV ret = SvIV(a) + SvIV(b);
	
	    XPUSHs(sv_2mortal(newSViv(ret)));
	    XSRETURN(1);
	}

前回よりぐっと本格的になっている。

	    if (items != 2) {
	        croak("Invalid argument count: %d", items);
	    }

ここで、引数の個数をチェックしている。`items` は引数の数をあらわす変数で、XS の中の人が勝手に用意してくれる変数のうちのひとつだ。せっかく用意してもらったのでありがたく使わせていただく。`croak` は Perl の `Carp::croak` とおなじように、ただ死ぬという関数である。Perl の `Carp::croak` とちがって、printf 的機能も内蔵しているのがちょっとちがうところなので注意。

	    SV *a = ST(0);
	    SV *b = ST(1);

`ST(n)` はスタックにつまれた値のうち、n番目のものをとりだすというマクロ。これもどうということはない。ただ第一引数と第二引数をとりだして変数にいれただけだ。

	    IV ret = SvIV(a) + SvIV(b);

`SvIV(SV*)` は SV 構造体の中にはいっている IV (整数値)をとりだすマクロだ。さて、ここで注意が必要なのが、Perl の世界では文字列と整数がなんとなく自動的に変換されるということだ。そう。この SvIV で、SV の中身が文字列だった場合も IV (整数値)に変換されるのだ。そういうわけなので `Sum::sum("5963", "4649")` のような呼出の場合でも問題なく処理はおこなわれる。

加算自体は普通の C レベルの加算となっていて、その結果を IV に保存している。IV は int ととかそういうものが typedef されたものだ(Configure script の設定によって IV のビット幅は変更されることに注意せよ)。

さて、計算がおわったので、いよいよ値を返却しよう。

	    XPUSHs(sv_2mortal(newSViv(ret)));

ここは3つもマクロ/関数がいりまじっていてちょっとだけややこしい。まずは内側から見ていこう。`newSViv(IV)` で、該当の IV をもった SV を生成している。IV は C の世界での整数型なので、そのまま Perl の世界にもどすことはできないのだ。Perl の世界であつかえるのはただ SV 型のみであることを思いだしていただきたい。

`sv_2mortal(SV*)` は、SV 構造体の SVs_TEMP フラッグをたてる君です。このフラッグがたっているとどうなるかというと、スコープをぬけたタイミングで、参照カウンタを1へらしてくれます。これはつまり、Objective-C でいうところの autorelease みたいなものだとおもってください。
<!-- (よりわかりやすい説明があるとよいとおもうので p-r 希望) -->

	    XSRETURN(1);

最後に XSRETURN(1) として、返り値の数を報告したらすべての作業は完了となる。

## コンテキストを読む XS

GIMME_V という値を参照することで、Perl における wantarray と同等のことができます。

	MODULE = Gimme          PACKAGE = Gimme
	
	void
	gimme(...)
	PPCODE:
	{
	    if (GIMME_V == G_ARRAY) {
            XPUSHs(sv_2mortal(newSViv(1)));
            XPUSHs(sv_2mortal(newSViv(2)));
            XPUSHs(sv_2mortal(newSViv(3)));
            XSRETURN(3);
        } else if (GIMME_V == G_VOID) {
            XSRETURN(0);
        } else if (GIMME_V == G_SCALAR) {
            XPUSHs(sv_2mortal(newSViv(5963)));
            XSRETURN(1);
        } else {
            abort();
        }
    }

GIMME_V は G_ARRAY, G_VOID, G_SCALAR のうちいずれかを取ります。

	use Gimme;
	say join(",", Gimme::gimme());
	say scalar(Gimme::gimme());

という風にすれば、

	1,2,3
	5963

という風に、コンテキストによりちがう値を返せていることがわかります。

## C の世界のポインタを扱う

たとえば以下のような「点」をあつかうライブラリがあったとしましょう。

	typedef struct {
	    int x;
	    int y;
	} Point;
	
	Point* Point_new(int x, int y) {
	    Point *p = malloc(sizeof(Point));  
	    p->x = x;
	    p->y = y;
	    return p;
	}
	
	void Point_free(Point* point) {
	    free(point);
	}

このとき、XS のコードは以下のように書けます。

	#define XS_STATE(type, x)     (INT2PTR(type, SvROK(x) ? SvIV(SvRV(x)) : SvIV(x)))

    #define XS_STRUCT2OBJ(sv, class, obj) \
        sv = newSViv(PTR2IV(obj));  \
        sv = newRV_noinc(sv); \
        sv_bless(sv, gv_stashpv(class, 1)); \
        SvREADONLY_on(sv);

    MODULE = Point		PACKAGE = Point		

    void
    new(...)
    PPCODE:
    {
        if (items != 3) {
            croak("Bad argument count: %d", items);
        }

        const char *klass = SvPV_nolen(ST(0));
        IV x = SvIV(ST(1));
        IV y = SvIV(ST(2));

        Point *point = Point_new(x, y);
        SV *sv;
        XS_STRUCT2OBJ(sv, klass, point);
        XPUSHs(sv_2mortal(sv));
        XSRETURN(1);
    }

    void
    x(...)
    PPCODE:
    {
        if (items != 1) {
            croak("Bad argument count: %d", items);
        }

        Point* point = XS_STATE(Point*, ST(0));
        XPUSHs(sv_2mortal(newSViv(point->x)));
        XSRETURN(1);
    }

    void
    y(...)
    PPCODE:
    {
        if (items != 1) {
            croak("Bad argument count: %d", items);
        }

        Point* point = XS_STATE(Point*, ST(0));
        XPUSHs(sv_2mortal(newSViv(point->y)));
        XSRETURN(1);
    }

    void
    DESTROY(...)
    PPCODE:
    {
        if (items != 1) {
            croak("Bad argument count: %d", items);
        }

        Point* point = XS_STATE(Point*, ST(0));
        Point_free(point);
        XSRETURN(0);
    }

以外とかわっている点はすくないですね。

    const char *klass = SvPV_nolen(ST(0));

`SvPV_nolen(SV*)` は、SV から `char*` つまり PV をとりだすという指令です。

そして、本題は XS_STRUCT2OBJ と XS_STATE の2つのマクロですね。どうみても。
それではこの2つをよんでいきましょう。

    #define XS_STRUCT2OBJ(sv, class, obj) \
        sv = newSViv(PTR2IV(obj));  \
        sv = newRV_noinc(sv); \
        sv_bless(sv, gv_stashpv(class, 1)); \
        SvREADONLY_on(sv);

4行もある! ややこしいですね。こんなのみてられないので、マクロを展開しながら考えてみましょう。

        Point *point = Point_new(x, y);
        SV *sv = newSViv(PTR2IV(point));
        sv = newRV_noinc(sv);
        sv_bless(sv, gv_stachpv(klass, 1));
        SvREADONLY_on(sv);
        XPUSHs(sv_2mortal(sv));
        XSRETURN(1);

はい。わかりやすくなりました! よね?

ではあらためて一行ずつよんでいきましょう。

        Point *point = Point_new(x, y);

C の API をよんで、ポインタをえました。

        SV *sv = newSViv(PTR2IV(point));

ポインタを `IV PTR2IV(void*)` のマクロで、IV 型に変換します。そして `SV* newSViv(IV)` で SV 型に変換。

        sv = newRV_noinc(sv);

これで、リファレンスにしています。ここまでで、`\do { my $ptr = 0xdeadfhbeef }` ってやったときの状態になっているわけですね。

        sv_bless(sv, gv_stachpv(klass, 1));

さらに、ここから bless します。`bless \do { my $ptr = 0xdeadfhbeef }, "Point"` とした状態になったわけです。gv_stashpv というのは stash ってやつをとりだす関数です。あまり深くかんがえなくていいです。



### 動作確認

以下のようにして動作確認ができます。

	use Point;
	my $p = Point->new(5,9);
	say $p->x; # => 5
	say $p->y; # => 9

## 基本的な Perl API

以下に基本的な Perl API について説明します。ベーシックな操作は網羅しているつもりですが、「これがあったほうがいいのでは?」という意見があれば github issues にておしらせください。

高速化のためにつかえるものや、2つの関数の組み合わせで可能な処理などについてはここには記述していません。

### SV の操作

#### SV の中身をダンプしたい

    use Devel::Peek;
    Dump($sv);

みたいなのを XS の世界ではどうやるのでしょうか?

    sv_dump(sv)

SV の中身をダンプして出力します。Devel::Peek::Dump とおなじです。
デバッグ時にはやたらとつかいます。

#### 新しい SV をつくりたい

    SV* new_sv = newSVsv(sv);

SVをコピーして新しいSVを作ります。XSの世界ではPerlの世界とちがって代入や配列への保存時にコピーが発生しないので、必要なときにきちんとコピーをしないとバグのもとになります。たとえば、XSUBの引数をオブジェクトに保存するときは`newSVsv`などでコピーすべきです。

#### 参照カウンターをインクリメントしたい

    SvREFCNT_inc(sv);

SV のリファレンスカウントをインクリメントします。

#### 参照カウンターをデクリメントしたい

    SvREFCNT_dec(sv);

SV のリファレンスカウントをインクリメントします。

#### SV 構造体から整数値(IV)をとりだしたい

    IV iv = SvIV(sv);

SV 構造体から IV をとりだします。IV がふくまれていない SV だった場合には、自動的に変換がはしります。

#### SV 構造体から浮動小数点値(NV)をとりだしたい

    NV nv = SvNV(sv);

SV 構造体から IV をとりだします。IV がふくまれていない SV だった場合には、自動的に変換がはしります。

#### SV 構造体から文字列をとりだしたい

    char* ptr = SvPV_nolen(SV* sv);

SV から文字列をとりだします。

文字列長さも必要なときは `SvPV()` をつかえばいいのですが、

    STRLEN len;
    char* ptr = SvPV(sv, len);

これは曲者。SV から文字列をとりだしつつ、長さの情報もえます。マクロでやってるので奇妙なかんじになってしまっている。
len のところにしれっと長さ情報がかきこまれます。

#### デリファレンスしたい

    if (SvROK(ref)) {
        SV *sv = SvRV(ref);
        sv_dump(sv);
    }

`SvRV` で、リファレンスの先をとりだすことができます。

ここで注意すべきは、`SvRV` をする前には `SvROK` でデリファレンス可能かどうかをチェックしておく必要があるってコト。
リファレンスじゃないものを SvRV すると一発で SEGV なので注意して!SvROK をよばないで

#### bless したいのですが

    bless $ref, 'Class';

みたいなのをやるにはどうしたらいいのでしょうか。

    ref = sv_bless(ref, gv_stash_pv("Class::Name", 1));

とすればいいです。ここで ref はリファレンスがはいった `SV*` で、`Class::Name` はクラス名です。

### 配列の操作

#### 配列をつくりたい

    my @av;

みたいなのをやるにはどうしたらいいのでしょうか。


    AV* av = newAV();

配列をつくります。できあがった変数のリファレンスカウントはもちろん1です。

#### 配列に値を push したい

    push @a, $sv;

みたいなのをやるにはどうしたらいいのでしょうか。

    av_push(av, newSVsv(sv));

配列に要素を push します。

`av_push` にかぎらず、配列やハッシュに保存するAPIはSVのコピーを行いませんので自分でコピーします。パフォーマンスのためにコピーを省略したい場合は、SvREFCNT_inc でリファレンスカウントを増やしてください。

#### 配列を pop したい

    $sv = pop @a;

みたいなのをやるにはどうしたらいいのでしょうか。

    SV* sv = av_pop(av);

`av_pop` で配列の要素を pop します。空の配列だったときには `&PL_sv_undef` がかえってきます。

#### 配列を shift したい

    $sv = shift @av;

みたいなのをやるにはどうしたらいいのでしょうか。

    SV* sv = av_shift(av);

配列の要素を shift します。Perl で `shift @a` するのとおなじです。

#### 配列を unshift したい。

    unshift @av, $sv;

みたいなのをやるにはどうしたらいいのでしょうか。

    av_unshift(av, newSVsv(sv));

``av_push`` と同じく、SVのコピーを作って入れます。

#### 配列の要素をとりだしたい

    my $key = 59;
    my $sv = $av[$key];

みたいなのをやるにはどうしたらいいのでしょうか。

    I32 key = 59;
    SV **ssv = av_fetch(av, key, 0)
    if (!ssv) { croak("av[59] is null"); }
    SV * sv = *sv;

`av_fetch` をつかいましょう。`SV**` がかえってくるので、NULL かどうかを確認するのをわすれずに。

#### 配列にデータを格納したい

    my $key = 59;
    $av[$key] = $sv;

みたいなのをやるにはどうしたらいいのでしょうか。

    I32 key = 59;
    sv_setsv(*av_fetch(av, key, TRUE), sv);

`av_store` を使うこともできますが、`av_store`には癖があるので`av_fetch`の第三引数lvalueをtrueにし、それに対して`sv_setsv`で代入するのがよいです。代入したい値がIVやNVなら、`sv_setsv`のかわりに`sv_setiv`や`sv_setnv`を使ってもかまいません。

使い方がややこしいので `av_push` や `av_unshift` ですませられるときは、そちらをつかっといた方が楽です。

### HV

#### ハッシュを宣言する

    my %hash;

新しい Hash をつくるには  `newHV()` をよびます。

    HV* = newHV();

この HV の参照カウントは1です。

### RV

### グローバル変数

#### `$Package::Name::Var` をとりだしたい

    SV * sv = get_sv("Package::Name::Var", GV_ADD);

`$Package::Variable` みたいなグローバル変数をとりだします。

第二引数には `GV_ADD` をわたせばなかったときには作成されます。0 をわたしたら、なかったときには NULL がかえります。
通常は `GV_ADD` わたしとく使い方がメインだとおもいます。

#### `@Package::Name::Var` をとりだしたい

    AV* av = get_av("Package::Name::Var", GV_ADD);

`@Package::Variable` みたいなグローバル変数をとりだします。

flags には `GV_ADD` をわたせばなかったときには作成されます。0 をわたしたら、なかったときには NULL がかえります。

## さらに上をめざす

本稿に書かれている範囲よりもさらに深く知りたいという方は以下のようなページを見てください。

### [perlxstut](http://perldoc.perl.org/perlxstut.html)
XS のチュートリアルドキュメントです。

### [perlapi](http://perldoc.perl.org/perlapi.html)
Perl の外部向け API が網羅されています。

### [perlguts](http://perldoc.perl.org/perlguts.html)
Perl の内部のことが解説されてます。

### [perlclib](http://perldoc.perl.org/perlclib.html)
C標準ライブラリを使用する際の、注意点(主に代替すべき API)について記載されています。

### [illguts](http://cpansearch.perl.org/src/RURBAN/illguts-0.44/index.html)

Perl の内部構造を画像まじりで解説してくれるページです。

## (コラム) C99 と XS

Visual Studio では C99 がサポートされていないので、C99 スタイルで書いてあるモジュールを CPAN にあげていると、バグレポートがくるので注意が必要です。

対応策は以下の3つのうちのいずれかです。

 * C89 スタイルになおす
 * Visual Studio を無視する
 * C++ としてアップする

XS モジュールを Windows でうごくようにがんばっても、そもそも OS の問題や Perl の Windows 対応の問題などで問題がおきて面倒なことになるだけだったりするので、Visual Studio のときは Makefile.PL で N/A にしてしまってもよいかな、と最近は考えています(重要なモジュールはのぞく)。

## まとめ

本稿は、いかがでしたでしょうか。XS を「書く」ことについての基本的な知識はついたのではないかとおもいます。

XS でいろいろかいて CPAN にジャンジャンとアップしましょう。

質問、ご要望は github issues にてうけつけていますので、お気軽にどうぞ。

## Contributors

### 監修

tokuhirom

### Contributors

 * gfx
 * Cside
 
