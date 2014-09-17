---
title: Turnipのステップ実行前後でスクショをとりたい時、どの辺のソースを読めばいいか
date: 2014-09-11 14:36 JST
tags:
- turnip
author: Atsushi Yasuda
---

初めまして。最近 CrowdWorks にジョインしたエンジニアの安田です。

弊社では受け入れテストを Cucumber から Tunrip へ移行を進めています。
Cucumber と比較するとかなりステップ定義が書きやすくなりました。
しかし、テストレポートはかなり控えめなものとなってしまいました。
特に、テスト失敗時のエラーメッセージがかなりわかりにくくなってしまっています。
下記の例などでは、ボタンが無かったというのはうっすらわかりますが、いったいどんな画面だったのかがわかりません。

![turnip-error-message](how-to-work-turnip-1.png "nil なのはわかるが……")

これを解決すべく、簡単ながら各ステップとスクリーンショットを記録できるよう、各ステップの開始・終了をキャプチャできる[パッチ](ここに gist への URI を貼りたい)を作成しました。
しかし、紹介記事とするには簡単すぎますし、機能も自分たちで使う分の最小限なので面白くありません。
世の中、「どうやって実現しているか」や「どういう機能があるか」について書かれた記事は多く見られますが、
「何をどう考えて作ったか」をまとめた記事はあまり見られません。
そこで、何をどう調査してパッチを作ったのか、レポート記事を作成してみようと思います。

## 前提

Turnip の詳しい説明は [るびまの記事](http://magazine.rubyist.net/?0042-FromCucumberToTurnip) が詳しいのでそちらにゆずるとします。
重要なのは、 [summary](https://github.com/jnicklas/turnip/blob/master/turnip.gemspec#L11) にも書かれている通り、 *Turnip は RSpec のエクステンション* だと言うことです。
RSpec の一部である以上、ステップごとのスクリーンショット等は CustomFormatter で行うのがベターでしょう。

しかし、現時点では Turnip ステップ実行前後に Formatter に通知が行きません。
ですので、簡単にはテスト失敗時に上記にあげたような豊かなデバッグ情報を残せません。

[TurnipFormatter](https://github.com/gongo/turnip_formatter) および [Gnawrnip](https://github.com/gongo/gnawrnip) の組み合わせを用いることで近しいことが可能となりますが、
この二つは画面遷移ごとにスクリーンショットが記録されます。
ステップごとにスクリーンショットや出力された html 等を確認したいという要望には、惜しくもあいません。

そこで、Turnip のステップ実行前後に Formatter へ通知が行われるように改造することにします。
そのために、次の 2 点を調査することとします。

* RSpec はどのように Formatter にイベントを通知するのでしょうか？
* また、 Turnip はどうやって feature ファイルを実行しているのでしょうか？

この 2 つがわかれば、改造も行えるはずです。

## RSpec はどのように Formatter にイベントを通知するのか

いきなりソースコードを読み始めても良いのですが、まずは RDoc をあさりましょう。
`RSpec::Core::Formatters` の [RDoc](http://rubydoc.info/gems/rspec-core/RSpec/Core/Formatters) にはビルトインの各種 `Formatter` の説明と、 `CustomFormatter` の作り方について記載されています。
既存のすべての通知の一覧等も載っていて大変便利ですね。
これだけいろいろな通知を受け取れるということは、何か `Formatter` へを通知する共通処理がありそうです。

`RSpec::Core::Formatters` の RDoc をよく読むと、 `RSpec::Core::Reporter` へ[リンク](http://rubydoc.info/gems/rspec-core/RSpec/Core/Reporter) が貼られています。
Overview にも記されている通り、この `RSpec::Core::Reporter` が通知機構の実装そのものです。
このクラスを使えば、自分たちの望む通知を送ることができそうです。
しかし、公開されているメソッドのうち、それっぽいメソッドは `report` だけです。
独自の通知送る場合にはこのメソッドを使えば良いのでしょうか？

残念ながら、 `report ` はテストスイート全体の開始と終了の通知に用いられています。

この辺で、ソースを読み始めましょう。
`report` の実装を読むと、即座に `start` を呼び出しています。
この `start` の実装はどのようになっているのでしょうか？

```ruby
# https://github.com/rspec/rspec-core/blob/v3.0.4/lib/rspec/core/reporter.rb#L61
def start(expected_example_count, time = RSpec::Core::Time.now)
  @start = time
  @load_time = (@start - @configuration.start_time).to_f
  notify :start, Notifications::StartNotification.new(expected_example_count, @load_time)
end
```

  ずいぶんと簡単かつ、 *とても通知をしていそう* なメソッドが見えます。
  ソースを眺めれば、`finish` や、 `example_group_finished` なども `notify` を使って通知をしていることがわかります。
  どうやらこんなメソッドを実装してやれば良さそうです。 `notify :step_startd, some_object` と呼び出せば、期待した動きになりそうです。

```ruby
# こんな感じのメソッドを実装してやれば良さそうだ。
def step_started(step)
  notify :step_started, Notifications::StepNotificaton.new(step)
end
```

ところで `start` や `example_passed` そして `notify` は `@private` がつけられています。
これらのメソッドを外から呼び出して大丈夫でしょうか？

ソースを読み進め `RSpec::Core::Reporter.example_passed` の呼び出しを確認してみましょう。
grep をすればわかりますが、呼び出し元は 1 箇所のみ。 `RSpec::Core::Example` 中で、直接 `reporter.example_passed` と呼び出しています。
RSpec の中から呼び出す分には問題なさそうです。

ここまで、ソースとドキュメントのみを追って、動きを予測してきました。
この予測が正しいか、きちんと実験して確認してみましょう。
下記の様な CustomFormatter を作って見ました。
予測が正しいのであれば、コールスタック上に `RSpec::Core::Reporter.report` からの一連の流れが確認できるはずです。

```ruby
# 呼び出し順の検証用フォーマッタ
require "rspec/core/formatters/base_text_formatter"

class TestFormatter < RSpec::Core::Formatters::BaseTextFormatter
  RSpec::Core::Formatters.register self, :example_passed

  def example_passed(notification)
    caller.each{|call| output.print call.to_s + "\n"}
  end
end
```

![turnip-error-message](how-to-work-turnip-2.png "example_passed から notify が呼ばれている")

動きも確認したので、早速 `step_started` を `RSpec::Core::Reporter` に実装していきましょう。
しかし、 RSpec のコードに手を入れるのはあまり行儀がよくありません。

ruby はオープンクラスです。今回は RSpec の動きを自分たちの為に変えたいだけですのでモンキーパッチを当てることにしましょう。

```ruby
# RSpec に当てるモンキーパッチ
module MonkeyPatch
  module RSpec
    module Core
      module Reporter
        StepNotification = Struct.new(:description, :keyword, :extra_args) do
          private_class_method :new

          # @api
          def self.from_step_object(data)
            new data.description, data.keyword, data.extra_args
          end
        end

        def step_started(step)
          notify :step_started, StepNotification.from_step_object(step)
        end

        def step_finished(step)
          notify :step_finished, StepNotification.from_step_object(step)
        end
      end
    end
  end
end

RSpec::Core::Reporter.send(:prepend, MonkeyPatch::RSpec::Core::Reporter)
```

これで、 `RSpec::Core::Reporter.step_started` が呼び出せるようになり、CustomFormatter で拾えるようになりました。

## Turnip はどのように spec を実行するか？

さて、次は Turnip のステップ実行前後に `step_started` と `step_finished` の呼び出しを挟みます。
どこに実装すれば良いか、ヒントになるのは *Turnip は RSpec のエクステンションということです* 。
RSpec の拡張と言っているのですから、 RSpec を拡張している場所が必ずあるはずです。

ソースを探せばすぐに見つかりますが、 [rspec.rb](https://github.com/jnicklas/turnip/blob/v1.2.2/lib/turnip/rspec.rb) というそのものズバリなファイルがあります。
このファイルでは `Turnip::RSpec::Loader` と `Turnip::RSpec::Execute` という 2 つのパッチが定義され、ファイル末尾で RSpec へパッチを当てています。

まずは `Turnip::RSpec::Loader` の方から見ていきましょう。

```ruby
# https://github.com/jnicklas/turnip/blob/v1.2.2/lib/turnip/rspec.rb#L12
module Turnip
  module RSpec
    module Loader
      def load(*a, &b)
        if a.first.end_with?('.feature') # ロードされたのが .feature ふぁいるなら
          require_if_exists 'turnip_helper'
          require_if_exists 'spec_helper'

          Turnip::RSpec.run(a.first) # turnip を起動！
        else
          super
        end
      end

      private

      def require_if_exists(filename)
        require filename
      rescue LoadError => e
        raise unless e.message.include?(filename)
      end
    end
  end
end

::RSpec::Core::Configuration.send(:include, Turnip::RSpec::Loader)
```

パッチのコードはそれだけ見るとわかりにくいですが、 `load` の挙動にパッチを当てています。
これによって、 `RSpec::Core::Configuration` 中で `load` を呼び出すと、上のコードが呼ばれることとなります。

より具体的には、 `RSpec::Core::Configuration.load_spec_files` で `load` を呼び出すときの動作がかわることとなります。

```ruby
# https://github.com/rspec/rspec-core/blob/v3.0.4/lib/rspec/core/configuration.rb#L1057
module RSpec
  module Core
    class Configuration
      def load_spec_files
        files_to_run.uniq.each {|f| load File.expand_path(f) } # パッチを当てることで、この load が Turnip::RSpec::Loader.load になる。
        @spec_files_loaded = true
      end
    end
  end
end
```

このパッチのおかげで、 `rspec` コマンド実行時に .feature ファイルでは Turnip が実行されるようになるのですね！

次に、 `Turnip::RSpec.run` を見ていきましょう。

```ruby
# https://github.com/jnicklas/turnip/blob/v1.2.2/lib/turnip/rspec.rb#L63
module Turnip
  module RSpec
    class << self
      def fetch_current_example(context)
        if ::RSpec.respond_to?(:current_example)
          ::RSpec.current_example
        else
          context.example
        end
      end

      def run(feature_file)
        Turnip::Builder.build(feature_file).features.each do |feature| # Turnip::Builder で Gherkin をパースします。
          ::RSpec.describe feature.name, feature.metadata_hash do # feature ごとに RSpec の describe を定義し...
            before do # before の定義もします！
              example = Turnip::RSpec.fetch_current_example(self)
              example.metadata[:file_path] = feature_file

              feature.backgrounds.map(&:steps).flatten.each do |step| # before で "前提" の各ステップが呼ばれるようにしてますね。
                run_step(feature_file, step)
              end
            end
            feature.scenarios.each do |scenario|
              instance_eval <<-EOS, feature_file, scenario.line # シナリオごとに describe を作っています！ そして、1 つの it を定義しています！
                describe scenario.name, scenario.metadata_hash do
                  it(scenario.steps.map(&:description).join(' -> ')) do # it は 1 つで
                    scenario.steps.each do |step| # 中では step をぐるぐるまわしていますね。
                      run_step(feature_file, step)
                    end
                  end
                end
              EOS
            end
          end
        end
      end
    end
  end
end
```

少々込み入っていますが、 `Turnip::Builder` で Geherkin をパースして、 RSpec の desribe ブロックを作り上げています！
これをみれば、Turnip で it が右の方に長くなる理由もよくわかりますね。

さて、ステップの実行は `Turnip::RSpec::Execute.run_step` で行われているのがわかります。
と、いうことは、この前後に `RSpec.configure.step_started` そして `RSpec.configure.step_finished` を呼びだしを加えれば、やりたいことは達成できます！

`RSpec::Core::Reporter` の時と同じく、モンキーパッチを当ててやりましょう！

```ruby
module MonkeyPatch
  module Turnip
    module RSpec
      module Execute
        # 各ステップを実行する。前後に RSpec::Core::Reporter に向けて、実行内容を通知する
        def run_step(feature_file, step)
          reporter = ::RSpec.configuration.reporter
          reporter.step_started(step)
          super(feature_file, step)
          reporter.step_finished(step)
        end
      end
    end
  end
end

::Turnip::RSpec::Execute.send(:prepend, MonkeyPatch::Turnip::RSpec::Execute)
```

## 調査が終わり

こうして自分の CustomFormatter で `step_started` と `step_finished` が受け取れるようになりました。
あとは、それぞれのコード中で、例えば `Capybara.current_session.save_screenshot` などを好きなだけ呼び出せるようになります。

実際に RSpec, Turnip に当てたモンキーパッチをご覧いただければわかりますが、かなり小さなコードだけでライブラリの動きに変化を与えることが可能です。

ruby のライブラリは非常にオープンかつ、かなり多くは小さな作りのライブラリです。
そして行うことの高機能さに比べ、単純な実装が多く見られます。

せっかくのオープンソースな世界です。秋の夜長に、自分の使っている gem のソースを読んで、ちょっと思い通りに動作を変えてみるのはいかがでしょうか？
