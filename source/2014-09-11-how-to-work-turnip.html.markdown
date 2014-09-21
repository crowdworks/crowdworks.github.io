---
title: Turnip のテストレポートを見やすくする技術
date: 2014-09-11 14:36 JST
tags:
- turnip
author: Atsushi Yasuda
---

Turnip のステップ実行毎にスクリーンショット (以下 SS) とレンダリングされた html を記録する Formatter を作った。
本投稿では、簡単な使い方の紹介およびどのようにステップを記録しているかについて述べる。

## 背景

Ruby on Rails での受け入れテストと言えば Cucumber が著名だが、ステップ定義にて正規表現を用いる点や RSpec との二本立てとなっている点などがネックとなっていた。
この２点を解決すべく Turnip が生まれた。 Turnip の詳しい説明は [るびまの記事](http://magazine.rubyist.net/?0042-FromCucumberToTurnip) が詳しいので割愛する。

しかし、テストレポートも RSpec のものに統合されたため、特にステップの失敗時のエラーメッセージがかなりわかりにくくなってしまった。

下記に例を示す。
この例では、とある画面にボタンが描画されていなかったため、ステップ実行に失敗したと予測されるが、結局どんな画面だったのかはわからない。

![turnip-error-message](how-to-work-turnip-1.png "nil なのはわかるが……")

ステップ失敗時の SS だけであれば、
[TurnipFormatter](https://github.com/gongo/turnip_formatter) および [Gnawrnip](https://github.com/gongo/gnawrnip) を用いれば記録することが可能だ。
しかし、 TurnipFormatter, Gnawrnip では、キャプチャのタイミングがページ遷移毎となっている。
javascript による制御が組み込まれた Web アプリケーションにおいては、もう少し細かなタイミングでのキャプチャが求められる。

## CapturefulFormatter の機能

TODO: ここに機能紹介

## CapturefulFormatter の実現方法

CapturefulFormatter は RSpec の CustomFormatter の一つとして実装した。
Trunip は RSpec の [エクステンション](https://github.com/jnicklas/turnip/blob/master/turnip.gemspec#L11) なので、 Turnip の実行記録をとる CapturefulFormatter も RSpec の機構に則るべきだと考えたためだ。

実装するためには二つの課題がある。

まず、 RSpec が各 Formatter にどのように通知を行っているかを把握する必要がある。ステップ実行前後の通知を Formatter に通知する方法を学ぶ。
次に、 Turnip がどのように feature を実行しているか、特に step の実行前後がどこにあるのかを把握する。通知のコードを実際に実装するためである。

### RSpec はどのように Formatter にイベントを通知するのか

`RSpec::Core::Formatters` の [RDoc](http://rubydoc.info/gems/rspec-core/RSpec/Core/Formatters) にはビルトインの各種 `Formatter` の説明と、 `CustomFormatter` の作り方について記載されている。
これだけいろいろな通知を受け取れるということは、何か `Formatter` へを通知する共通処理があると予測できる。
`RSpec::Core::Reporter` へ[リンク](http://rubydoc.info/gems/rspec-core/RSpec/Core/Reporter) が貼られており、このクラスが通知機構の実装そのものだとわかる。
しかし、公開されているメソッドのうち、それっぽいメソッドは `report` だけであり、引き数もそれっぽくない。
よって、ソースコードを読み解くこととする。

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

`report` の実装を読むと、即座に `start` を呼び出している。

```ruby
# https://github.com/rspec/rspec-core/blob/v3.0.4/lib/rspec/core/reporter.rb#L61
def start(expected_example_count, time = RSpec::Core::Time.now)
  @start = time
  @load_time = (@start - @configuration.start_time).to_f
  notify :start, Notifications::StartNotification.new(expected_example_count, @load_time)
end
```

`start` では上記の通り `notify` を呼び出すだけだ。

```ruby
# https://github.com/rspec/rspec-core/blob/v3.0.4/lib/rspec/core/reporter.rb#L135
def notify(event, notification)
  registered_listeners(event).each do |formatter|
    formatter.__send__(event, notification)
  end
end
```

`notify` で具体的に通知を行っている。
ソースを眺めれば、`finish` や、 `example_group_finished` なども `notify` を使って通知をしているのが見て取れる。
これらに習い、 `step_started` を実装し、その内部で `noify :step_started` としてやることとした。

```ruby
# こんな感じのメソッドを実装してやれば良さそうだ。
def step_started(step)
  notify :step_started, Notifications::StepNotificaton.new(step)
end
```

ところで RSpec のコードに手を入れるのはさすがに避けたい。
そこで、今回はモンキーパッチを当てることとした。

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

これで、 `RSpec::Core::Reporter.step_started` が呼び出せるようになり、CustomFormatter で拾えるようになった。

### Turnip がどのように step を実行するか

Turnip は RSpec の拡張であり、実行コマンドも

```
rspec spec/acceptance/attack_monster.feature
```

のように `rspec` を用いる。

よって、* RSpec を拡張している場所がソースコード中にある* と予測できる。
ファイル名の通りであるが、それをしているのが [turnip/lib/turnip/rspec.rb](https://github.com/jnicklas/turnip/blob/v1.2.2/lib/turnip/rspec.rb) だ。
このファイル中では `Turnip::RSpec::Loader` と `Turnip::RSpec::Execute` という二つのクラスが用意され、ファイル末尾で `Turnip::RSpec::Loader` を RSpec にパッチしている。

それぞれの挙動を、まずは `Turnip::RSpec::Loader` の方から見ていく。

```ruby
# https://github.com/jnicklas/turnip/blob/v1.2.2/lib/turnip/rspec.rb#L12
module Turnip
  module RSpec
    module Loader
      def load(*a, &b) # load メソッドを定義
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

このパッチは `load` を定義し、 `RSpec::Core::Configuration` にあてている。
これによって、 `RSpec::Core::Configuration` 中で `load` を呼び出すと、上のコードが呼ばれることとなり、指定されたのが `.feature` なら Turnip が処理するとわかる。

より具体的には、 `RSpec::Core::Configuration.load_spec_files` での挙動が、これにより変化する。

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

このパッチにより、 `rspec` コマンド実行時に `.feature` ファイルでは Turnip が実行されるようになる。

さて、 `Turnip::RSpec::Loader.load` では `.feature` ファイルロード時に `Turnip::RSpec.run` を実行していた。
`Turnip::RSpec.run` を見ていく。

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

少し複雑に見えるが、 `Turnip::Builder` で Gherkin をパースして、 RSpec の desribe ブロックを作り上げ、それを実行しているだけだとわかる。
シナリオごとに describe ブロックを定義し、 `it(scenario.steps.map(&:description).join(' -> '))` により一つの it 句が一つのシナリオに対応するというのも見て取れる。
そして、ステップの実行は `Turnip::RSpec::Execute.run_step` で行われているというのもわかる。
`RSpec::Core::Reporter` の時と同様に、 `run_step` 前後に通知を行うモンキーパッチを作成することとする。

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

ここまでの二つのパッチを当てることで、自分の独自 Formatter で step 前後の動きを記録できる。
CapturefulFormatter では、単純に `Capybara.current_session.save_screenshot` を行い、 SS を保存している。

## むすび

ここまで記してきたように、本投稿ではステップごとの SS を記録する Fomatter の誕生理由と、その実現方法について述べてきた。
実際の CapturefulFormatter は、ステップごとの情報を記録した後、テスト終了時に erb をもとにレポートを作成する機能などが実装されている。
しかし、コアとなるステップ前後の hook 追加については、上記に示した二つのパッチのみで実現できる。

よって、例えば上記パッチのみを `spec/support` 以下に実装し、読者自身の CustomFormatter を定義することも簡単だ。
せっかくの受け入れテストであり、ステップごとにスクリーンショットを撮りたい。読者の中にそのような要望があれば、本投稿を役立てていただければ幸いだ。
