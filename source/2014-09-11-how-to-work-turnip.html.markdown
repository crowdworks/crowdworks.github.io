---
title: Turnipのステップ実行前後でスクショをとりたい時、どの辺のソースを読めばいいか
date: 2014-09-11 14:36 JST
tags:
  - turnip
author: Atsushi Yasuda
---

この記事は、RSpec と Turnip のソースコードを *読み進めるだけ* の記事です。

初めまして。最近 CrowdWorks にジョインしたエンジニアの安田です。

弊社では受け入れテストを Cucumber から Tunrip へ移行を進めています。
Cucumber と比較すると、かなりステップ定義が書きやすくなりましたが、
反面、テストレポートはかなり控えめなものとなりました。
特に、テスト失敗時のエラーメッセージがかなりわかりにくくなってしまっています。

<!-- ここにキャプション。説明文として、「じゃあ何が表示されてたんだよ！」と -->

これを解決すべく、簡単ながら各ステップとスクリーンショットを記録する gem を作成しました。
しかし、紹介記事とするには簡単すぎますし、機能も自分たちで使う分の最小限なので面白くありません。

さて gem の一番のミソは各ステップの開始と終了を RSpec の Formatter に通知する所です。
世の中、「どうやって実現しているか」や「どういう機能があるか」について書かれた記事は多く見られますが、
「何をどう考えて作ったか」をまとめた記事はあまり見られません。
せっかくなので、何をどう調査し、考えて行ったのか、レポートしてみます。

## 前提

Turnip の詳しい説明は [るびまの記事](http://magazine.rubyist.net/?0042-FromCucumberToTurnip) が詳しいのでそちらにゆずるとして　
[summary](https://github.com/jnicklas/turnip/blob/master/turnip.gemspec#L11) にも書かれている通り、 *Turnip は RSpec のエクステンション* です。

現時点では Turnip ステップ実行前後に hook を挟むことができません。
とすると、テスト失敗時に豊かな上記にあげたようなデバッグ情報を残すのは難しそうです。
[TurnipFormatter](https://github.com/gongo/turnip_formatter) および [Gnawrnip](https://github.com/gongo/gnawrnip) の組み合わせを用いることで近しいことが可能となります
しかし、そこそこの規模で組まれた javascript がある場合などでは、
ステップごとにスクリーンショットや出力された html 等を確認したいという要望にかられます。

TurnipFormatter は RSpec の CustomFormatter として実装されており、その主要機能は haml によるレポート出力です。
一方、 Gnawrnip は Capybara でのページ遷移を hook し、スクリーンショットを記録します。

この設計を参考にしつつ発展させ、 RSpec の CustomFormatter としてステップ実行の前後の挙動をかけるようにすれば、やりたいことが達成しやすくなると考えられます。

方針は決まりました。
解決すべき問題は 2 つです。
RSpec はどのように Formatter にイベントを通知するのでしょうか？
また、 Turnip はどうやって feature ファイルを実行しているのでしょうか？

## RSpec はどのように Formatter にイベントを通知するのか

ruby の各種 gem では、大切な情報はきちんと RDoc に書かれています。
`RSpec::Core::Formatters` の [RDoc]() にはビルトインの各種 `Formatter` の説明と、 `CustomFormatter` についての情報が記載されています。
私たちの目的は、既に定義されている `example_group_started` 等のように、 `step_started`, `step_finished` を定義することです。
RDoc に書かれている通りのバラエティに富んだ通知を受け取れるということは、何か `Formatter` へ `Notification` を通知する共通処理がありそうです。

`RSpec::Core::Formatters` の RDoc をよく読むと、 `RSpec::Core::Reporter` へリンクが貼られているます。
リンクをたどり RDoc を読むと、そこにはそのものズバリの概要が書かれており、 `RSpec` の各種処理中、このクラスを用いて `Formatter` へイベントを通知しているのだとわかります。
このクラスを使えば、自分たちの望む通知を送ることができそうです。
これで安心したいところですが、 RDoc に記載されたメソッドのうち、通知を行いそうなものは `report` だけです。
step 関連の通知にはこのメソッドを使えば良いのでしょうか？

残念ながら、 `report ` の引数、RDoc に記された説明、そしてソースコードのいずれもが
このメソッドはテストスイート全体の `report` であることを示しています。
このメソッドを呼び出すだけで `step_started` が `Formatter` で呼び出されるという予測は考えが甘かったようです。

<!-- ここに RDoc のキャプション: report :step_started とはできなさそうだ -->

この辺で、オープンソースの最大のメリットを享受しましょう。
フリーソフトウェアには改造の自由があります。
プログラムは書かれた通り動き、そして RSpec はそのソースが公開されています。

さて、 `report` の実装を読むと、即座に `start` を呼び出しています。
この `start` の実装はどのようになっているのでしょうか？

```ruby
# @private
def start(expected_example_count, time = RSpec::Core::Time.now)
  @start = time
  @load_time = (@start - @configuration.start_time).to_f
  notify :start, Notifications::StartNotification.new(expected_example_count, @load_time)
end
```

ずいぶんと簡単かつ、とてもメッセージを送っていそうなメソッドが見えます。
ソースを眺めれば、他の Notification も `notify` を使って呼ばれていることがすぐにわかります。
どうやら `notify :step_startd, some_object` と呼び出せば、期待した動きになりそうです。

`start` や `example_passed` そして `notify` は `@private` がつけられています。
これらのメソッドを外から呼び出して大丈夫でしょうか？

ソースを読み進め `RSpec::Core::Reporter.example_passed` の呼び出しを確認してみましょう。
grep をすればわかりますが、呼び出し元は 1 箇所のみ。 `RSpec::Core::Example` 中で、直接 `reporter.example_passed` としています。
これなら呼び出しても問題はないでしょう。　

どうやら `RSpec::Core::Reporter` に `step_started` を実装し、その中で `notify` を呼び出せば良さそうです。

本当でしょうか？
少なくとも `example_passed` がどのように呼び出されるか、きちんと確認すべきでしょう。
読んできた内容が正しいのであれば、コールスタック上に `RSpec::Core::Reporter.report` からの一連の流れが確認できるはずです。
テスト用の `Formatter` を作ることで確認して見ましょう。

```ruby
require "rspec/core/formatters/base_text_formatter"

class TestFormatter < RSpec::Core::Formatter::BaseTextFormatter
  RSpec::Core::Formatters.register self, :example_passed

  def example_group_finished(notification)
    output.print caller
  end
end
```

簡単な spec を定義し、実行した結果を見たところ、予想通りのコールスタックが確認できます。
`step_started`, `step_finished` を `RSpec::Core::Reporter` へ実装し、それを呼び出せば目的は達成可能です。

<!-- ここにキャプション:やった、きちんと呼び出し順が予想通りだ -->

やり方は何通りかありますが、せっかくなので ruby の良さを生かすべく、モンキーパッチが良いでしょう。
問題が 1 つ解決しました。
しかし、まだもう 1 つ大きな問題が残っています。
どのように `step_started` や `step_finished` を呼び出せば良いのか、次は Turnip のソースを読んでいく必要があります。

## Turnip はどのように spec を実行するか？

*Turnip は RSpec のエクステンションです* 。
summary にも書いてありますが、これが最初のとっかかりになります。

RSpec の拡張と言っているのですから、 RSpec を拡張している場所が必ずあるはずです。
Turnip の実装は非常に短いので、すぐに見つかるでしょう。

lib ディレクトリを見ればすぐにわかりますが、 [rspec.rb]() というそのものズバリなファイルがあります。
早速見てみましょう。

`Turnip::RSpec::Loader` と `Turnip::RSpec::Execute` という 2 つのパッチが定義され、ファイル末尾で RSpec へパッチを当てています。

`Turnip::RSpec::Loader` はコメントに書かれている通り、 `load` の挙動にパッチを当てています。
具体的には `RSpec::Core::Configuration.load_spec_files` での、スペック定義ファイルを load するときの動作に変化を加えています。

```ruby
def load_spec_files
  files_to_run.uniq.each {|f| load File.expand_path(f) } # パッチを当てることで、この load が Turnip::RSpec::Loader.load になる。
  @spec_files_loaded = true
end
```

このパッチにより、 .feature ファイルが指定されたときは Turnip が実行されるようになります。
ちょうど下で定義されている `Turnip::RSpec.run` が呼び出されます。
この `Turnip::RSpec.run` こそ Turnip のミソの 1 つであり、読んでいるだけで大変楽しいところではあります。
今回やりたいこととあまり関係がないので省略しますが、ぜひ読んで噛み砕いてみてください!!

さて、ソースを読んだ感じ、ステップの実行は `Turnip::RSpec::Execute.run_step` で行われているようです。
この前後で `RSpec.configure.step_started` そして `RSpec.configure.step_finished` を呼べば、すべての目的は達成できそうです。

## 調査が終わり

こうして 2 つの大きな問題が解決し、自分の CustomFormatter で `step_started` と `step_finished` が受け取れるようになりました。
Tunrnip のコードの小ささを見てわかる通り、あくまでも Turnip は RSpec 上で Gherkin で書かれたシナリオを読み、ステップを定義しているだけにすぎません。
欲しかったスクリーンショットや html は Capybara が担っており、CustomFormatter から `Capybara.current_session` を呼び出すことで、好きなだけ保存できます。

実際に RSpec, Turnip に当てたモンキーパッチをご覧いただければわかりますが、かなり小さなコードだけでライブラリの動きに変化を与えることが可能です。

ruby のライブラリは非常にオープンかつ、かなり多くは小さな作りのライブラリです。
そして行うことの高機能さに比べ、単純な実装が多く見られます。

せっかくのオープンソースな世界です。
自由にライブラリのソースコードを読み、そして自由に改造たり、新たなライブラリを作ってみてはいかがでしょうか？？
