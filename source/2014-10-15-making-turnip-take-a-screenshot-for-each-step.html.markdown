---
title: Turnip のテストレポートを見やすくしてみた
date: 2014-10-15 18:00 JST
tags:
- turnip
- testing
author: Atsushi Yasuda
ogp:
  og:
    image:
      '': http://engineer.crowdworks.jp/images/how-to-work-turnip-og.png
      type: image/png
      width: 300
      height: 176
atom:
  image:
    url: http://engineer.crowdworks.jp/images/how-to-work-turnip-og.png
    type: image/png
---

Turnipのステップ実行毎にスクリーンショット(以下SS)とレンダリングされたhtmlを記録するFormatter、[CapturefulFormatter](http://github.com/ayasuda/CapturefulFormatter)を作りました。
本記事では、簡単な使い方の紹介と、どのようにステップを記録しているかについて記していきます。

## 背景

Ruby on Railsでの受け入れテストと言えばCucumberが著名ですが、ステップ定義にて正規表現を用いる点や、RSpecとの二本立てとなっている点などが課題となっていました。
この２点を解決すべく生まれたのがTurnipです。Turnipの詳しい説明は [るびま42号のTurnip解説記事](http://magazine.rubyist.net/?0042-FromCucumberToTurnip) が詳しいので割愛します。

しかし、Turnip では、テストレポートもRSpecのものを使うため、特にステップの失敗時のエラーメッセージがかなりわかりにくくなってしまいました。

下記に例を示します。とある画面にボタンが描画されていなかったため、ステップ実行に失敗したと予測されるテスト結果です。ですが、結局どんな画面だったのかはわかりません。

![turnip-error-message](how-to-work-turnip-1.png "nil なのはわかるが……")

ステップ失敗時のSSを撮るために生まれたのが
[TurnipFormatter](https://github.com/gongo/turnip_formatter) および [Gnawrnip](https://github.com/gongo/gnawrnip) です。
大変便利なgemですが、TurnipFormatterとGnawrnipの組み合わせは、キャプチャのタイミングがページ遷移毎となっており、細かなタイミングでのキャプチャが得られません。
javascriptによる制御が組み込まれたWebアプリケーションでは、もう少し細かなタイミングでのキャプチャが欲しくなりますし、
受け入れテストのレポートにするならば、ステップごとのキャプチャが欲しくなります。

## CapturefulFormatter の機能

CapturefulFormatterは、Turnipのステップごとに、ステップ名とスクリーンショット、描画されたhtmlの3つを記録するシンプルなFormatterです。
各ステップのスクリーンショットと描画されたhtmlが保存されるため、いざバグが発生したときなど、調査がよりスムーズに行えるようになるでしょう。

このFormatter使うことで、こんな感じのテストレポートが生成できます。

![captureful_report](how-to-work-turnip-3.png "生成されたレポート")

非常にわかりやすいレポートが生成されるので、エンジニアだけでなく、他部門のメンバーにもテスト結果がスムーズに共有できます。
また、新しく参加するメンバーのためのマニュアルとしても活用できるかと思います。

レポートのテンプレート等のカスタマイズもサポートしていますので、ユーザ独自のきれいなレポートを作成することも可能です。
その他、実装して欲しい機能の要望などがあれば、Githubにて提案いただければ幸いです。

## CapturefulFormatter の実現方法

CapturefulFormatterはRSpecのCustomFormatterの一つとして実装しました。
これは、TurnipはRSpecの [エクステンション](https://github.com/jnicklas/turnip/blob/master/turnip.gemspec#L11) なので、
Turnipの実行記録をとるCapturefulFormatterもRSpecの機構に則るべきだと考えたためです。

実装するためには二つの課題がありました。

まず、RSpecが各Formatterにどのように通知を行っているかを把握する必要があります。ステップ実行前後の通知をFormatterに通知する方法を調べましょう。
次に、Turnipがどのようにfeatureを実行しているか、特にstepの実行前後がどこにあるのかを把握しましょう。そうすることで、先ほど調べたFormatterへの通知を実際に実装できるようになります。

### RSpec はどのように Formatter にイベントを通知するのか

`RSpec::Core::Formatters` の [RDoc](http://rubydoc.info/gems/rspec-core/RSpec/Core/Formatters) にはビルトインの各種 `Formatter` の説明と、 `CustomFormatter` の作り方について記載されています。
これだけいろいろな通知を受け取れるということは、何か `Formatter` へを通知する共通処理があると予測できるでしょう。
このページを良く読むと、 `RSpec::Core::Reporter` へ[リンク](http://rubydoc.info/gems/rspec-core/RSpec/Core/Reporter) が貼られているのがわかります。
このクラスが通知機構の実装そのものです。
しかし、公開されているメソッドのうち、それっぽいメソッドは `report` だけであり、引き数もそれっぽくありません。
確認するために、ソースコードを見てみましょう。

`report` の実装を読むと、即座に `start` を呼び出しているのがわかります。

```ruby
# https://github.com/rspec/rspec-core/blob/v3.0.4/lib/rspec/core/reporter.rb#L51
def report(expected_example_count)
  start(expected_example_count)
  begin
    yield self
  ensure
    finish
  end
end
```

`start` では `notify` を呼び出すだけです。

```ruby
# https://github.com/rspec/rspec-core/blob/v3.0.4/lib/rspec/core/reporter.rb#L61
def start(expected_example_count, time = RSpec::Core::Time.now)
  @start = time
  @load_time = (@start - @configuration.start_time).to_f
  notify :start, Notifications::StartNotification.new(expected_example_count, @load_time)
end
```

`notify` で具体的に通知を行っているのがわかります。

```ruby
# https://github.com/rspec/rspec-core/blob/v3.0.4/lib/rspec/core/reporter.rb#L135
def notify(event, notification)
  registered_listeners(event).each do |formatter|
    formatter.__send__(event, notification)
  end
end
```

周辺のソースを眺めれば、`finish` や、 `example_group_finished` なども `notify` を使って通知をしているのが見て取れます。
今回は、これらに習い、 `step_started` を実装し、その内部で `noify :step_started` としてやることとしました。

```ruby
# こんな感じのメソッドを実装してやれば良さそうだ。
def step_started(step)
  notify :step_started, Notifications::StepNotificaton.new(step)
end
```

ところで、このコードをRSpecのコード中に直接書くのは、あまりスマートではありません。
そこで、今回はモンキーパッチを当てることとし、下記の様なコードが実装されています。

```ruby
# RSpec に当てるモンキーパッチ
module CapturefulFormatter
  module RSpec
    module Core
      module Reporter
        # Formatter へ送る構造体。今回は ExampleNotification の実装を参考にした。
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

RSpec::Core::Reporter.send(:prepend, CapturefulFormatter::RSpec::Core::Reporter)
```

これで、 `RSpec::Core::Reporter.step_started` が呼び出せるようになり、CustomFormatterで拾えるようになりました!!

### Turnip がどのように step を実行するか

TurnipはRSpecの拡張であり、実行コマンドも

```
rspec spec/acceptance/attack_monster.feature
```

のように `rspec` を用います。

と、いうことは、* RSpec を拡張している場所がソースコード中にある* はずです。
ファイルの一覧を眺めれば、それっぽいファイルがすぐにみつかるでしょう。 [turnip/lib/turnip/rspec.rb](https://github.com/jnicklas/turnip/blob/v1.2.2/lib/turnip/rspec.rb) です。
このファイル中では `Turnip::RSpec::Loader` と `Turnip::RSpec::Execute` という二つのクラスが用意され、ファイル末尾で `Turnip::RSpec::Loader` を RSpec にパッチしています。
パッチを当てやすいのは、`Ruby`の特長ですね!!

それぞれの挙動を、まずは `Turnip::RSpec::Loader` の方から見ていきましょう。

この `Turnip::RSpec::Loader` は `load` を定義し、 `RSpec::Core::Configuration` にあてています。
このパッチによって、 `RSpec::Core::Configuration` 中で `load` を呼び出すと、上のコードが呼ばれることとなり、指定されたのが `.feature` なら Turnip が処理することになります。

```ruby
# https://github.com/jnicklas/turnip/blob/v1.2.2/lib/turnip/rspec.rb#L12
module Turnip
  module RSpec
    module Loader

      # ここで load メソッドをオーバーライド
      def load(*a, &b)
        if a.first.end_with?('.feature') # ロードされたのが .feature ファイルなら...
          require_if_exists 'turnip_helper'
          require_if_exists 'spec_helper'

          Turnip::RSpec.run(a.first) # turnip が起動！！
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

より具体的には、 `RSpec::Core::Configuration.load_spec_files` での挙動が、このパッチのおかげで変化します。
これで、 `rspec` コマンド実行時に `.feature` ファイルが読み込まれた場合、Turnipが実行されるようになります。

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

さて、 `Turnip::RSpec::Loader.load` では `.feature` ファイルロード時に `Turnip::RSpec.run` を実行していたのを覚えているでしょうか。
次は、いよいよ `Turnip::RSpec.run` を見ていきましょう。

少し複雑に見えるが、 `Turnip::Builder` で Gherkin をパースして、RSpecの `desribe` ブロックを作り上げ、それを実行しているだけのコードです。

シナリオごとに `describe` ブロックを定義しており、 `it(scenario.steps.map(&:description).join(' -> '))` により1つのシナリオからを1つのit句を作っています。
そして、各ステップの実行は `Turnip::RSpec::Execute.run_step` で行われています。

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
                      run_step(feature_file, step) # ここがステップ実行の本体です
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

さて、ステップ実行の本体が `run_step` だとわかりましたので、早速、 `RSpec::Core::Reporter` の時と同様に、 `run_step` 前後に通知を行うモンキーパッチを作成しましょう。

```ruby
module CapturefulFormatter
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

::Turnip::RSpec::Execute.send(:prepend, CapturefulFormatter::Turnip::RSpec::Execute)
```

ここまでの2つのパッチを当てることで、独自Formatterでstep前後の動きを記録できるようになりました!!

CapturefulFormatterでは、単純に `Capybara.current_session.save_screenshot` を行い、SSを保存しています。

## むすび

ここまで記してきたように、本記事ではステップごとの SS を記録するFomatterの誕生理由と、その実現方法について述べてきました。
実際のCapturefulFormatterでは、ステップごとの情報を記録した後、テスト終了時にerbをもとにレポートを作成する機能なども実装されています。
しかし、コアとなるステップ前後のhook追加については、上記に示した二つのパッチのみで実現できるのが、おわかりいただけたでしょうか。

本記事の方法を使えば、例えば上記パッチのみを `spec/support` 以下に実装することで、読者自身のCustomFormatterを定義することも簡単です。
せっかく、わかりやすい受け入れテストの記述ができますし、スクリーンショットも簡単に撮ることができるので、読者の中にそのような要望があれば、本記事を役立てていただければ幸いです。
