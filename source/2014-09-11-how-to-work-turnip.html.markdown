---
title: how-to-work-turnip
date: 2014-09-11 14:36 JST
tags:
  - turnip
author: Atsushi Yasuda
---

初めまして。最近 CrowdWorks にジョインしたエンジニアの安田です。

弊社では受け入れテストを Cucumber から Tunrip へ移行を進めています。
Cucumber と比較すると、かなりステップ定義が書きやすくなりましたが、
反面、テストレポートはかなり控えめなものとなりました。
特に、テスト失敗時のエラーメッセージがかなりわかりにくくなってしまっています。

<!-- ここにキャプション。説明文として、「じゃあ何が表示されてたんだよ！」と -->

そこで、簡単ながら各ステップとスクリーンショットを記録する gem を作成しました。
しかし、紹介記事とするには簡単すぎますし、機能も自分たちで使う分の最小限なので面白くありません。

この gem の一番の機能は各ステップ前後での処理であり、それを実現させるミソとなる部分は実質10行程度です。
その 10 行、実装者が何をどの順番で調べて作っていったか、今回はそれを記事にしてみようと思います。
世の中の技術ブログを見ると「どう作ったか」に着目している記事はなかなかないので、吉と出るか凶と出るか…

## 前提

Turnip の詳しい説明はるびまの記事が詳しいのでそちらにゆずるとして　
summary にも書かれている通り、 Turnip は RSpec のエクステンションです。

Turnip において
TurnipFormatter および Gnawrip の組み合わせを用いることで近しいことが可能となります
しかし、そこそこの規模で組まれた javascript がある場合などでは、
ステップごとにスクリーンショットや出力された html 等を確認したいという要望にかられます。


方針は決まりました。
解決すべき問題は２つです。
RSpec はどのように Formatter にイベントを通知するのでしょうか？
また、 Turnip はどうやって feature ファイルを実行しているのでしょうか？


## RSpec はどのように Formatter にイベントを通知するのか

RSpec::Core::Formatters の RDoc にはビルトインの各種 Formatter の説明と、CustomFormatter についてが書かれています。
ここに step_started, step_finished を定義するのが目的です。
バラエティに富んだ通知を受け取れるということは、何か、 Formatter へ Notification を通知する共通の何かがありそうです。

RDoc をよく読むと、 RSpec::Core::Reporter への参照が示されています。
RSpec::Core::Reporter の RDoc にはそのものズバリの概要が書かれており、
RSpec の各種機構は、このクラスを用いて Formatter へイベントを通知しているのだとわかります。
このクラスを使えば、自分たちの望む通知を送ることができそうです。
RDoc にのせられている、通知を行いそうなメソッドは report だけです。
step 関連の通知にはこのメソッドを使えば良いのでしょうか？

残念ながら、report の引数、RDoc に記された説明、そしてソースコードのいずれもが
このメソッドはテストスイート全体の report であることを示しています。
このメソッドを呼び出すだけで step_started が Formatter に送るというのはできなさそうです。

視点を変えて、オープンソースの最大のメリットを享受しましょう。
プログラムは書かれた通り動き、RSpec はそのソースが公開されています。
RDoc にのせられたソースによれば、 report メソッドは即座に start を呼び出しています。
この start の実装はどのようになっているのでしょうか？

```ruby
# @private
def start(expected_example_count, time = RSpec::Core::Time.now)
  @start = time
  @load_time = (@start - @configuration.start_time).to_f
  notify :start, Notifications::StartNotification.new(expected_example_count, @load_time)
end
```

ずいぶんと簡単かつ、とてもメッセージを送っていそうなメソッドが呼び出されているとわかります。
ソースを眺めれば、他の Notification も notify を使って呼ばれていることがすぐにわかります。
どうやら notify に :step_startd を引数にして呼び出せば、期待した動きになりそうです。

ところで、 start や example_passed , そして notify は @private が指示されています。
これを外から呼び出してしまって良いのでしょうか？

RSpec::Core::Reporter.example_passed の呼び出しを確認してみましょう。
grep をすればわかりますが、呼び出し元は 1 箇所のみ
RSpec::Core::Example 中で、直接 reporter.example_passed としています。

ここまで読んだことで、どうやら RSpec::Core::Reporter に step_started を実装し、その中で notify を呼び出せば良さそうです。

ところで、ここまでの過程は本当でしょうか？
少なくとも example_passed がどのように呼び出されるか、きちんと確認すべきでしょう。
テスト用の Formatter を作ることで確認します。

```ruby
require "rspec/core/formatters/base_text_formatter"

class TestFormatter < RSpec::Core::Formatter::BaseTextFormatter
  RSpec::Core::Formatters.register self, :example_passed

  def example_group_finished(notification)
    output.print caller
  end
end
```

簡単な spec を定義し、実行した結果を見たところ、予想通りの call stack が示されています。
step_started, step_finished を RSpec::Core::Reporter へ実装し、それを呼び出せば目的は達成できます。
やり方は何通りかありますが、せっかくなので ruby の良さを生かすべく、モンキーパッチを当てることで対応すれば良いでしょう。

問題が１つ解決しました。
しかし、まだもう１つ大きな問題が残っています。
どのように実装した step_started や step_finished を呼び出せば良いか、ソースを読んでいく必要があります。

## Turnip はどのように spec を実行するか？

Turnip は RSpec のエクステンションです。
summary にも書いてありますが、これが最初のとっかかりになります。
RSpec の１部として振る舞うのですから、 RSpec を拡張している場所が必ずあるはずです。
Turnip の実装は非常に短いので、すぐに見つかるでしょう。

lib ディレクトリを見ればすぐにわかりますが、 rspec.rb というそのものズバリなファイルがそのものです。
パッチを当てるならよくある方法だとも思いますが、ファイル末尾で RSpec の拡張対象に include を行いっています。
そう、モンキーパッチがこれであたります。　

大きく言って２つのパッチがあたっています。Turnip::RSpec::Loader と Turnip::RSpec::Execute です。

より簡単なのは Loader の方で、これにより .feature ファイルが指定されたときは Turnip を違う場合は RSpec 本体が実行されるようになります。

実際にパッチがあたるのは Module::load
rspec-core/lib/rspec/core/configuration.rb:1057
の load が発動したタイミングで Turnip::RSpec::Loader::load が呼ばれるようになり、

turnip/lib/turnip/rspec.rb:72
の run が発動する。

> これで Turnip::Builder.build の中で Gherkin がパースされ、フィーチャごとに ::RSpec::describe が出来上がる。
> この中では before とかが適宜定義されつつ、 feature.scenarios.each ごとに
> instance_eval が呼ばれ、動的に rspec の describe が形成される。
> そして、1 シナリオが 1 example (it) に対応するのが見て取れる。
> これらは即時に解釈・実行される。

中で呼ばれてるの見りゃわかるけど run_step。

run_step 起動直後に step(step) されるけど、これの定義はもちろん include されている Turnip::Execute に。
これで各ステップが実行されるのです。

## 調査が終わり

こうして２つの大きな問題が解決し、自分の CustomFormatter で step_started, step_finished が受け取れる用になりました。
スクリーンショットや html は Capybara が司っており、 Capybara.current_session から好きなだけ呼び出せます。
今回作成した gem では、特にこだわりがなかったのでキャプチャしたファイルやステップの実行結果などを erb を使って最後にレポートでまとめています。

実際に RSpec, Turnip に当てたモンキーパッチをご覧いただければわかりますが、かなり小さなコードだけでライブラリの動きに変化を与えることが可能です。
実質的に８行ほどです。

時間をかけて８行ですから、外から見ればサボっていると言われてしまうかも知れません。
しかし、なるべくソースを書かない


