#@# :author: 小林茂雄
bigdecimal は浮動小数点数演算ライブラリです。
任意の精度で 10 進表現された浮動小数点数を扱えます。

=== 他の数値オブジェクトとの変換 (coerce)

BigDecimal オブジェクトが算術演算子の左にあるときは、
BigDecimal オブジェクトが右にあるオブジェクトを
(必要なら) BigDecimal に変換してから計算します。
従って、BigDecimal オブジェクト以外でも数値を意味するものなら
右に置けば演算は可能です。

ただし、文字列は (通常) 数値に自動変換することはできません。
文字列を数値に自動変換したい場合は bigfloat.c の
「/* #define ENABLE_NUMERIC_STRING */」のコメントを外してから、
再コンパイル、再インストールする必要があります。
文字列で数値を与える場合は注意が必要です。
数値に変換できない文字があると、
単に変換を止めるだけでエラーにはなりません。
"10XX"なら 10、"XXXX"は 0 と扱われます。

   a = BigDecimal.E(20)
   c = a * "0.123456789123456789123456789"   # 文字を BigDecimal に変換してから計算

無限大や非数を表す文字として、
"Infinity"、"+Infinity"、"-Infinity"、"NaN" も使用できます
(大文字・小文字を区別します)。
ただし、mode メソッドで false を指定した場合は例外が発生します。
また、BigDecimalクラスは coerce(Ruby本参照)をサポートしています。
従って、BigDecimal オブジェクトが右にある場合も大抵は大丈夫です。
ただ、現在の Ruby インタプリタの仕様上、文字列が左にあると計算できません。

  a = BigDecimal.E(20)
  c = "0.123456789123456789123456789" * a   # エラー

必要性があるとは思いませんが、
どうしてもと言う人は String オブジェクトを継承した新たなクラスを作成してから、
そのクラスで coerce をサポートしてください。

=== 無限、非数、ゼロの扱い

「無限」とは表現できないくらい大きな数です。
特別に扱うために +Infinity (正の無限大) や
-Infinity (負の無限大) と表記されます。
無限は 1.0/0.0 のようにゼロで割るような計算をしたときに生成されます。

「非数」は 0.0/0.0 や Infinity-Infinity 等の結果が定義できない計算をしたときに生成されます。非数は NaN(Not a Number)と表記されます。 NaN を含む計算は全て NaN になります。また NaN は自分も含めて、どんな数とも一致しません。

ゼロは +0.0 と -0.0 が存在します。ただし、+0.0 == -0.0 は true です。

Infinity、NaN、 +0.0 と -0.0 等を含んだ計算結果は組み合わせにより複雑です。興味のある人は、以下のプログラムを実行して結果を確認してください(結果について、疑問や間違いを発見された方はお知らせ願います)。

  require "bigdecimal"
  
  aa  = %w(1 -1 +0.0 -0.0 +Infinity -Infinity NaN)
  ba  = %w(1 -1 +0.0 -0.0 +Infinity -Infinity NaN)
  opa = %w(+ - * / <=> > >=  < == != <=)
  
  for a in aa
    for b in ba
      for op in opa
        x = BigDecimal::new(a)
        y = BigDecimal::new(b)
        eval("ans= x #{op} y;print a,' ',op,' ',b,' ==> ',ans.to_s,\"\n\"")
      end
    end
  end

=== 内部構造

BigDecimal内部で浮動小数点は構造体(Real)で表現されます。
そのうち仮数部は unsigned long の配列 (以下の構造体要素 frac) で管理されます。
概念的には、以下のようになります。

  <浮動小数点数> = 0.xxxxxxxxx * BASE ** n

ここで、x は仮数部を表す数字、BASE は基数 (10 進表現なら 10)、
n は指数部を表す整数値です。BASEが大きいほど、大きな数値が表現できます。
つまり、配列のサイズを少なくできます。
BASE は大きいほど都合がよいわけですが、デバッグのやりやすさなどを考慮して、
10000になっています (BASE は VpInit() 関数で自動的に計算します)。
これは 32 ビット整数の場合です。64ビット整数の場合はもっと大きな値になります。
残念ながら、64 ビット整数でのテストはまだやっていません。
もし、テストをした方がいれば結果を教えてください。
BASE が 10000 のときは、以下の仮数部の配列 (frac) の各要素には最大で 4 桁の数字が格納されます。

浮動小数点構造体 (Real) は以下のようになっています。

  typedef struct {
     unsigned long MaxPrec; // 最大精度(frac[]の配列サイズ)
     unsigned long Prec;    // 精度(frac[]の使用サイズ)
     short    sign;         // 以下のように符号等の状態を定義します。
                            //  ==0 : NaN
                            //    1 : +0
                            //   -1 : -0
                            //    2 : 正の値
                            //   -2 : 負の値
                            //    3 : +Infinity
                            //   -3 : -Infinity
     unsigned short flag;   // 各種の制御フラッグ
     int      exponent;     // 指数部の値(仮数部*BASE**exponent)
     unsigned long frac[1]; // 仮数部の配列(可変)
  } Real;

例えば BASE=10000 のとき 1234.56784321 という数字は、

    0.1234 5678 4321*(10000)**1

ですから frac[0] = 1234、frac[1] = 5678、frac[2] = 4321、
Prec = 3、sign = 2、exponent = 1 となります。
MaxPrec は Prec より大きければいくつでもかまいません。
flag の使用方法は実装に依存して内部で使用されます。

=== 2 進と 10 進

BigDecimal は <浮動小数点数> = 0.xxxxxxxxx*10**n という 10 進形式で数値を保持します。
しかし、計算機の浮動小数点数の内部表現は、
言うまでもなく <浮動小数点数> = 0.bbbbbbbb*2**n という 2 進形式が普通です
(x は 0 から 9 まで、b は 0 か 1 の数字)。
BigDecimal がなぜ 10 進の内部表現形式を採用したのかを以下に説明します。

=== 10 進のメリット

==== デバッグのしやすさ

まず、プログラム作成が楽です。
frac[0]=1234、frac[1]=5678、frac[2]=4321、 exponent=1、sign=2
なら数値が 1234.56784321 であるのは見ればすぐに分かります。 

==== 10進表記された数値なら確実に内部表現に変換できる

例えば、以下のようなプログラムは全く誤差無しで計算することができます。
以下の例は、一行に一つの数値が書いてあるファイル file の合計数値を求めるものです。

   file = File::open(....,"r")
   s = BigDecimal::new("0")
   while line = file.gets
      s = s + line
   end

この例を 2 進数で計算すると誤差が入る可能性があります。
例えば 0.1 を2進で表現すると
0.1 = b1*2**(-1)+b1*2**(-2)+b3*2**(-3)+b4*2**(-4) ……
と無限に続いてしまいます (b1=0,b2=0,b3=0,b4=1...)。
ここで bn(n=1,2,3,...) は 2進を表現する 0 か 1 の数字列です。
従って、どこかで打ち切る必要があります。ここで変換誤差が入ります。
もちろん、これを再度 10 進表記にして印刷するような場合は
適切な丸め操作(四捨五入)によって再び "0.1" と表示されます。
しかし、内部では正確な 0.1 ではありません。 

==== 有効桁数は有限である (つまり自動決定できる)

0.1 を表現するための領域はたった一つの配列要素 (frac[0] = 1) で済みます。
配列要素の数は10進数値から自動的に決定できます。
これは、可変長浮動小数点演算では大事なことです。
逆に 0.1 を 2 進表現したときに 2 進の有効桁をいくつにするのかは、
0.1 という数値だけからは決定できません。 

=== 10 進のデメリット

実は今までのメリットは、そのままデメリットにもなります。
そもそも、10 進を 2 進に変換するような操作は
変換誤差を伴う場合を回避することはできません。
大概のコンピュータは 10 進の内部表現を持っていないので、
BigDecimal を利用して誤差無しの計算をする場合は、
計算速度を無視しても最後まで BigDecimal を使用続ける必要があります。

==== 最初は何か？

自分で計算するときにわざわざ 2 進数を使う人は極めてまれです。
計算機にデータを入力するときもほとんどの場合、 10進数で入力します。
その結果、double 等の計算機内部表現は最初から誤差が入っている場合があります。
BigDecimal はユーザ入力を誤差無しで取り込むことができます。
デバッグのしやすさと、データ読みこみ時に誤差が入らないという 2 点が実際のメリットです。

==== 計算精度について

c = a op b という計算 (op は + - * /) をしたときの動作は以下のようになります。

  (1) 乗算は (a の有効桁数) + (b の有効桁数)、
      除算は (a の最大有効桁数) + (b の最大有効桁数) 分の最大桁数
      (実際は、余裕を持って、もう少し大きくなります) を持つ変数 c を新たに生成します。
      加減算の場合は、誤差が出ないだけの精度を持つ c を生成します。
      例えば c = 0.1+0.1*10**(-100) のような場合、c の精度は100桁以上の精度を持つようになります。
  (2) 次に c = a op b の計算を実行します。

このように、加減算と乗算での c は必ず「誤差が出ない」だけの精度を持って生成されます
(BigDecimal.limit を指定しない場合)。
除算は (a の最大有効桁数) + (b の最大有効桁数) 分の最大桁数を持つ c が生成されますが、
c = 1.0/3.0 のような計算で明らかなように、
c の最大精度を超えるところで計算が打ち切られる場合があります。

いずれにせよ、c の最大精度は a や b より大きくなりますので
c が必要とするメモリー領域は大きくなることに注意して下さい。

注意：「+, -, *, /」では結果の精度(有効桁数)を自分で指定できません。
精度をコントロールしたい場合は、以下のインスタンスメソッドを使用します。

: add, sub, mult, div

  これらのメソッドは先頭 (最左) の数字からの桁数を指定できます。

    BigDecimal("2").div(3,12) # 2.0/3.0 => 0.6666666666 67E0

: truncate, round, ceil, floor

  これらのメソッドは小数点からの相対位置を指定して桁数を決定します。

    BigDecimal("6.66666666666666").round(12) # => 0.6666666666 667E1

==== 自分で精度をコントロールしたい場合

自分で精度(有効桁数)をコントロールしたい場合は add、sub、mult、div 等のメソッドが使用できます。以下の円周率を計算するプログラム例のように、求める桁数は自分で指定することができます。

  #!/usr/local/bin/ruby
  
  require "bigdecimal"
  #
  # Calculates 3.1415.... (the number of times that a circle's diameter
  # will fit around the circle) using J. Machin's formula.
  #
  def big_pi(sig) # sig: Number of significant figures
    exp    = -sig
    pi     = BigDecimal::new("0")
    two    = BigDecimal::new("2")
    m25    = BigDecimal::new("-0.04")
    m57121 = BigDecimal::new("-57121")
  
    u = BigDecimal::new("1")
    k = BigDecimal::new("1")
    w = BigDecimal::new("1")
    t = BigDecimal::new("-80")
    while (u.nonzero? && u.exponent >= exp) 
      t   = t*m25
      u   = t.div(k,sig)
      pi  = pi + u
      k   = k+two
    end
  
    u = BigDecimal::new("1")
    k = BigDecimal::new("1")
    w = BigDecimal::new("1")
    t = BigDecimal::new("956")
    while (u.nonzero? && u.exponent >= exp )
      t   = t.div(m57121,sig)
      u   = t.div(k,sig)
      pi  = pi + u
      k   = k+two
    end
    pi
  end
  
  if $0 == __FILE__
    if ARGV.size == 1
      print "PI("+ARGV[0]+"):\n"
      p big_pi(ARGV[0].to_i)
    else
      print "TRY: ruby pi.rb 1000 \n"
    end
  end




= class BigDecimal

BigDecimal は可変長浮動小数点計算機能ライブラリです。

#@# inner-file index here

=== はじめに

「有効桁数」とは BigDecimal が精度を保証する桁数です。ぴったりではありません、若干の余裕を持って計算されます。また、例えば32ビットのシステムでは10進で4桁毎に計算します。従って、現状では、内部の「有効桁数」は4の倍数となっています。

以下のメソッド以外にも、(C ではない) Ruby ソースの形で提供されているものもあります。例えば、

  require "bigdecimal/math.rb"

とすることで、sin や cos といった関数が使用できるようになります。使用方法など、詳細は math.rb の内容を参照して下さい。 その他、Float との相互変換などのメソッドが util.rb でサポートされています。利用するには

  require "bigdecimal/util.rb"

のようにします。詳細は util.rb の内容を参照して下さい。

=== 例

  require 'bigdecimal'
  a = BigDecimal::new("0.123456789123456789")
  b = BigDecimal("123456.78912345678",40)
  c = a + b

== Class Methods

--- BigDecimal(s [, n])
--- BigDecimal.new(s [, n])

新しい BigDecimal オブジェクトを生成します。
s は数字を表現する初期値を文字列で指定します。スペースは無視されます。また、判断できない文字が出現した時点で文字列は終了したものとみなされます。 n は必要な有効桁数(a の最大有効桁数)を整数で指定します。 n が 0 または省略されたときは、n の値は s の有効桁数とみなされます。 s の有効桁数より n が小さいときも n=0 のときと同じです。 a の最大有効桁数は n より若干大い値が採用されます。最大有効桁数は以下のような割り算を実行するとき等に意味を持ちます。

    BigDecimal("1")    / BigDecimal("3")    # => 0.3333333333 33E0
    BigDecimal("1",10) / BigDecimal("3",10) # => 0.3333333333 3333333333 33333333E0

ただし、個々の演算における最大有効桁数 n の取り扱いは将来のバージョンで若干変更される可能性があります。 

--- BigDecimal.mode(s [, v])

BigDecimalの実行結果を制御します。
第2引数を省略、または nil を指定すると現状の設定値が戻ります。
以下の使用方法が定義されています。

[例外処理]

計算結果が非数(NaN)やゼロによる除算になったときの処理を定義することができます。

//emlist{
f = BigDecimal::mode(BigDecimal::EXCEPTION_NaN,flag)
f = BigDecimal::mode(BigDecimal::EXCEPTION_INFINITY,flag)
f = BigDecimal::mode(BigDecimal::EXCEPTION_UNDERFLOW,flag)
f = BigDecimal::mode(BigDecimal::EXCEPTION_OVERFLOW,flag)
f = BigDecimal::mode(BigDecimal::EXCEPTION_ZERODIVIDE,flag)
f = BigDecimal::mode(BigDecimal::EXCEPTION_ALL,flag)
//}

  * EXCEPTION_NaN は結果が NaN になったときの指定です。
  * EXCEPTION_INFINITY は結果が無限大(±Infinity)になったときの指定です。
  * EXCEPTION_UNDERFLOW は指数部がアンダーフローするときの指定です。
  * EXCEPTION_OVERFLOW は指数部がオーバーフローするときの指定です。
  * EXCEPTION_ZERODIVIDE はゼロによる割り算を実行したときの指定です。
  * EXCEPTION_ALL は、可能な全てに対して一括して設定するときに使用します。

flag が true のときは、指定した状態になったときに例外を発行するようになります。
flag が false(デフォルト)なら、例外は発行されません。計算結果は以下のようになります。

  * EXCEPTION_NaN のとき、非数(NaN)
  * EXCEPTION_INFINITY のとき、無限(+ or -Infinity)
  * EXCEPTION_UNDERFLOW のとき、ゼロ
  * EXCEPTION_OVERFLOW のとき、+Infinity か -Infinity
  * EXCEPTION_ZERODIVIDE のとき、+Infinity か -Infinity

EXCEPTION_INFINITY、EXCEPTION_OVERFLOW、EXCEPTION_ZERODIVIDE は今のところ同じです。
戻り値は、設定後の値です。「値」の意味は、例えば BigDecimal::EXCEPTION_NaNと「値」の & が ゼロ以外ならば EXCEPTION_NaNが設定されているという意味です。

[丸め処理指定]

計算途中の丸め操作の指定ができます。

  f = BigDecimal::mode(BigDecimal::ROUND_MODE,flag) 

の形式で指定します。
ここで、flag は以下(括弧内は対応するインスタンスメソッド)の一つを指定します。

  * ROUND_UP 全て切り上げます。
  * ROUND_DOWN 全て切り捨てます(truncate)。
  * ROUND_HALF_UP 四捨五入します(デフォルト)。
  * ROUND_HALF_DOWN 五捨六入します。
  * ROUND_HALF_EVEN 四捨六入します。5の時は上位1桁が奇数の時のみ繰り上げます(Banker's rounding)。
  * ROUND_CEILING 数値の大きい方に繰り上げます(ceil)。
  * ROUND_FLOOR 数値の小さい方に繰り下げます(floor)。

戻り値は指定後の flag の値です。第2引数に nil を指定すると、現状の設定値が返ります。 mode メソッドでは丸め操作の位置をユーザが指定することはできません。丸め操作と位置を自分で制御したい場合は BigDecimal::limit や truncate/round/ceil/floor、 add/sub/mult/div といったインスタンスメソッドを使用して下さい。 

--- limit([n])

生成されるBigDecimalオブジェクトの最大桁数をn桁に制限します。戻り値は設定する前の値です。設定値のデフォルト値は0で、桁数無制限という意味です。 n を指定しない、または n が nil の場合は、現状の最大桁数が返ります。
計算を続行する間に、数字の桁数が無制限に増えてしまうような場合 limit で予め桁数を制限できます。この場合 BigDecimal.mode で指定された丸め処理が実行されます。ただし、インスタンスメソッド (truncate/round/ceil/floor/add/sub/mult/div) の桁数制限は limit より優先されます。

    mf = BigDecimal::limit(n)

--- double_fig

Ruby の Float クラスが保持できる有効数字の数を返します。

    p BigDecimal::double_fig  # ==> 20 (depends on the CPU etc.)

double_figは以下の C プログラムの結果と同じです。

    double v = 1.0;
    int double_fig = 0;
    while (v + 1.0 > 1.0) {
       ++double_fig;
       v /= 10;
    }

== Methods

--- +(other)

    加算 (c = a + b)。
    c の精度については「計算精度について」を参照してください。 

--- -(other)

    減算 (c = a - b)、または符号反転 (c = -a)。
    c の精度については「計算精度について」を参照してください。 

--- *(other)

    乗算 (c = a * b)。
    c の精度は (a の精度) + (b の精度) 程度です。
    詳しくは「計算精度について」を参照してください。 

--- self / other

    除算 (c = a / b)。
    c の精度については「計算精度について」を参照してください。 

--- add(b, n)

以下のように使用します。

  c = a.add(b, n)

c = a + b を最大で n 桁まで計算します。
a + b の精度が n より大きいときは
BigDecimal.mode で指定された方法で丸められます。
n がゼロなら + と同じです。 

--- sub(b, n)

のように使用します。

    c = a.sub(b,n)

c = a - b を最大で n 桁まで計算します。
a - b の精度が n より大きいときは
BigDecimal.mode で指定された方法で丸められます。
n がゼロなら - と同じです。 

--- mult(b, n)

以下のように使用します。

    c = a.mult(b,n)

c = a * b を最大で n 桁まで計算します。
a * b の精度が n より大きいときは
BigDecimal.mode で指定された方法で丸められます。
n がゼロなら * と同じです。 

--- div(b [, n])

以下のように使用します。

    c = a.div(b,n)

c = a / b を最大で n 桁まで計算します。
a / b の精度が n より大きいときは
BigDecimal.mode で指定された方法で丸められます。
n がゼロなら / と同じです。
n が省略されたときは [[m:Float#div]] と同様に結果が BigDecimal になります。 

--- fix

self の小数点以下の切り捨て。

--- frac

self の整数部分の切り捨て。

--- floor([n])

a 以下の最大整数 (BigDecimal 値) を返します。

    c = BigDecimal("1.23456").floor      # => 1
    c = BigDecimal("-1.23456").floor     # => -2

以下のように引数 n を与えることもできます。
n >= 0 なら、小数点以下 n + 1 位の数字を操作します
(小数点以下を、最大 n 桁にします)。
n が負のときは小数点以上 n 桁目を操作します
(小数点位置から左に少なくとも n 個の 0 が並びます)。

    c = BigDecimal("1.23456").floor(4)   # => 1.2345
    c = BigDecimal("15.23456").floor(-1) # => 10.0

--- ceil([n])

a 以上の整数のうち、最も小さい整数を計算し、
その値 (BigDecimal 値)を返します。

    c = BigDecimal("1.23456").ceil   # => 2
    c = BigDecimal("-1.23456").ceil  # => -1

以下のように引数を与えて、小数点以下 n+1 位の数字を操作することもできます。
n >= 0 なら、小数点以下 n + 1 位の数字を操作します
(少数点以下を、最大 n 桁にします)。
n が負のときは小数点以上 n 桁目をを操作します
(小数点位置から左に少なくとも n 個の 0 が並びます)。

    c = BigDecimal("1.23456").ceil(4)    # => 1.2346
    c = BigDecimal("15.23456").ceil(-1)  # => 20.0

--- round(n [, b])

クラスメソッド BigDecimal::mode(BigDecimal::ROUND_MODE,flag) で指定した
ROUND_MODE に従って丸め操作を実行します。 
BigDecimal::mode(BigDecimal::ROUND_MODE,flag) で何も指定せず、
かつ、引数を指定しない場合は
「小数点以下第一位の数を四捨五入して整数(BigDecimal 値)」にします。

    c = BigDecimal("1.23456").round   # => 1
    c = BigDecimal("-1.23456").round  # => -1

以下のように引数を与えて、小数点以下 n+1 位の数字を操作することもできます。
n が正の時は、小数点以下 n+1 位の数字を丸めます(少数点以下を、最大 n 桁にします)。
n が負のときは小数点以上 n 桁目を丸めます(小数点位置から左に少なくとも n 個の 0 が並びます)。

    c = BigDecimal("1.23456").round(4)    # => 1.2346
    c = BigDecimal("15.23456").round(-1)  # => 20.0

2番目の引数を指定すると、BigDecimal#mode の指定を無視して、
指定された方法で丸め操作を実行します。

    c = BigDecimal("1.23456").round(3,BigDecimal::ROUND_HALF_EVEN)   # => 1.234
    c = BigDecimal("1.23356").round(3,BigDecimal::ROUND_HALF_EVEN)   # => 1.234

--- truncate

小数点以下の数を切り捨てて整数 (BigDecimal 値)にします。
以下のように引数を与えて、小数点以下 n+1 位の数字を操作することもできます。
n が正の時は、小数点以下 n+1 位の数字を切り捨てます
(少数点以下を、最大 n 桁にします)。 
n が負のときは小数点以上 n 桁目を操作します
(小数点位置から左に少なくとも n 個の 0 が並びます)。

    c = BigDecimal("1.23456").truncate(4)    # => 1.2345
    c = BigDecimal("15.23456").truncate(-1)  # => 10.0

--- abs

a の絶対値

    c = a.abs

--- to_i

少数点以下を切り捨てて整数に変換します。

  i = a.to_i

i は値に応じて Fixnum か Bignum になります。
a が Infinity や NaN のとき、i は nil になります。 

--- to_f

Float オブジェクトに変換します。
よりきめ細かい値が必要ならば split メソッドを利用してください。 

--- to_s([n])

文字列に変換します (デフォルトは "0.xxxxxEn" の形になります)。

    BigDecimal("1.23456").to_s  #  ==> "0.123456E1"

引数 n に正の整数が指定されたときは、少数点で分けられる左右部分を、
それぞれ n 桁毎に空白で区切ります。

    BigDecimal("0.1234567890123456789").to_s(10)   # => "0.1234567890 123456789E0"

引数 n に正の整数を表す文字列を指定することもできます。

    BigDecimal("0.1234567890123456789").to_s("10") # => "0.1234567890 123456789E0"

文字列の最初に '+' (または ' ') を付けると、値が正の場合、
先頭に '+' (または ' ')が付きます。負の場合は常に '-' が付きます。

    BigDecimal("0.1234567890123456789").to_s(" 10") # => " 0.1234567890 123456789E0"
    BigDecimal("0.1234567890123456789").to_s("+10") # => "+0.1234567890 123456789E0"
    BigDecimal("-0.1234567890123456789").to_s("10") # => "-0.1234567890 123456789E0"

さらに文字列の最後に E (または e) か F (または f) を指定することで、
以下のように表示形式を変更することができます。

    BigDecimal("1234567890.123456789").to_s("E")  # => "0.1234567890123456789E10"
    BigDecimal("1234567890.123456789").to_s("F")  # => "1234567890.123456789"
    BigDecimal("1234567890.123456789").to_s("5E") # => "0.12345 67890 12345 6789E10"
    BigDecimal("1234567890.123456789").to_s("5F") # => "12345 67890.12345 6789"

--- exponent

指数部を整数値で返します。

    n = a.exponent

は a の値が 0.xxxxxxx*10**n を意味します。 

--- precs

a の有効数字 (n) と最大有効数字 (m) の配列を返します。 

    n, m = a.precs

--- sign

値が正 (sign > 0)、負 (sign < 0)、その他 (sign == 0) であるかの情報を返します。

    n = a.sign

としたとき n の値は a が以下のときを意味します。
() の中の数字は、実際の値です (「内部構造」を参照)。

    n = BigDecimal::SIGN_NaN(0)                 # a は NaN
    n = BigDecimal::SIGN_POSITIVE_ZERO(1)       # a は +0
    n = BigDecimal::SIGN_NEGATIVE_ZERO(-1)      # a は -0
    n = BigDecimal::SIGN_POSITIVE_FINITE(2)     # a は正の値
    n = BigDecimal::SIGN_NEGATIVE_FINITE(-2)    # a は負の値
    n = BigDecimal::SIGN_POSITIVE_INFINITE(3)   # a は+Infinity
    n = BigDecimal::SIGN_NEGATIVE_INFINITE(-3)  # a は-Infinity

--- nan?

a.nan? は a が NaN のとき真を返します。 

--- infinite?

a.infinite? は a が+∞のとき 1 、-∞のときは -1、
それ以外のときは nil を返します。 

--- finite?

a.finite? は a が∞または NaN でないとき真を返します。 

--- zero?

a が 0 なら true を返します。 

    c = a.zero? 

--- nonzero?

a が 0 なら nil、0 以外なら a そのものが返ります。

    c = a.nonzero? 

--- split

BigDecimal 値を 0.xxxxxxx*10**n と表現したときに、
符号 (NaNのときは 0、それ以外は+1か-1になります)、
仮数部分の文字列("xxxxxxx")と、基数(10)、更に指数 n を配列で返します。

    a = BigDecimal::new("3.14159265")
    f, x, y, z = a.split

とすると、f =+ 1、x = "314159265"、y = 10、z = 1 になります。
従って、

    s = "0."+x
    b = f*(s.to_f)*(y**z)

で Float に変換することができます。 

--- inspect

デバッグ出力に使用されます。

    p a = BigDecimal::new("3.14",10)

とすると、[0x112344:'0.314E1',4(12)] のように出力されます。
最初の16進数はオブジェクトのアドレス、次の '0.314E1' は値、
次の4は現在の有効桁数(表示より若干大きいことがあります)、
最後はオブジェクトが取り得る最大桁数になります。 

--- **(other)

a の n 乗を計算します。n は整数。

      c = a ** n

結果として c の有効桁は a の n 倍以上になるので注意。 

--- power

メソッド演算子 ** と同じで、a の n 乗を計算します。n は整数。

    c = a.power(n)

結果として c の有効桁は a の n 倍以上になるので注意。 

--- sqrt

a の有効桁 n 桁の平方根 (n の平方根ではありません) をニュートン法で計算します。

    c = a.sqrt(n)

--- divmod(n)

詳細は [[m:Float#divmod]] を参照して下さい。 

--- quo(n)

詳細は [[m:Float#quo]] を参照して下さい。 

--- modulo(n)

詳細は [[m:Float#modulo]] を参照して下さい。 

--- %(n)

詳細は [[m:Float#%]] を参照して下さい。 

--- remainder(n)

詳細は [[m:Float#remainder]] を参照して下さい。 

--- <=>(other)

a == b なら 0、a > b なら 1、a < b なら -1 になります。

    c = a <=> b 

--- ==(other)

.

--- ===(other)

.

--- <(other)

.

--- <=(other)

.

--- >(other)

.

--- >=(other)

.

