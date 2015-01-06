---
title: Polymer で Rails アプリに絵文字ボタンを！（１）Polymer on Rails
date: 2015-01-08 11:00 JST
tags:
  - web_components
  - polymer
  - frontend
author: Atushi Yasuda
ogp:
  og:
    image:
      '': http://engineer.crowdworks.jp/images/middleman.png
      type: image/png
      width: 400
      height: 400
atom:
  image:
    url: http://engineer.crowdworks.jp/images/middleman.png
    type: image/png
published: false
---

安田です。
Web Components がいよいよ本格的に使われ始めるのは今年かも知れません。
年明けからスタートダッシュを切るべく、Web の UI に革命を起こし得るこの技術について紹介出来たらと思います。

本記事は３回に分けて連載します。
初回の今回は Polymer の説明と、Ruby on Rails や Rack で Polymer を使用する為の方法について紹介します。
来週投稿予定である第２回では、最初から提供されているコンポーネントの説明や公開されているコンポーネントの探し方、
そして取り入れたコンポーネントのカスタマイズ方法について見ていきます。
21日に公開予定である第３回では実践編として、テキストフォームへ絵文字を入力しやすくする
「絵文字パネル」コンポーネントの実装を行います。

本連載を楽しんで頂ければ幸いです。

Web Components とは？
----

Polymer の登場
----

Polymer のインストール方法
----

さっそくPolymerを試してみましょう!!
公式サイトの[ガイド](https://www.polymer-project.org/docs/start/getting-the-code.html)によれば、
Polymerはbowerでのインストールが推奨されています。
bowerについての詳細は割愛しますが、フロントエンド向きのパッケージマネージャです。

bowerを用いたPolymerのインストール手順はとても簡単です。
以下のコマンドを実行することで、Polymerが使用可能になります。

```
$ cd /path/to/project
$ bower init
$ bower install --save Polymer/polymer
$ bower update
```

Polymerをインストールしたら、早速Polymerを使用したWebページを作ってみましょう。
以下のような内容で、index.htmlを作成します。

```
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <script src="bower_components/webcomponentsjs/webcomponents.min.js"></script>
    <link rel="import" href="bower_components/paper-elements/paper-elements.html">
  </head>
  <body>
    <h1>Try Polymer!</h1>
    <p>Hello, Polymer and Web Components!</p>
  </body>
</html>
```

ファイルを作成し終わったら、早速ブラウザで確認しましょう。
少し注意が必要ですが、`file://`を使用して、ブラウザから直接ファイルを開くことは出来ません。
これは、`<link rel="import">` つまり、HTML importsを使用している為で、
HTML imporstはセキュリティの関係上 `file://` からファイルを読み込めない為です。

RubyやPyhtonがインストールされているのであれば、次のコマンドで簡単なWebサーバがすぐに立ち上げられます。

```
$ python -m SimpleHTTPServer 8000 # Python2 の場合
$ python3 -m http.server 8000 # Python3 の場合
$ ruby -run -e httpd . -p 8000
```

Webサーバを立ち上げることで、ブラウザから`http://localhost:8000`にアクセスすることで、
先のindex.htmlの内容が確認できます。

この状態では、特段コンポーネントを読み込んでいませので、特に面白いことが起きる訳ではありません。
ですので、早速用意されているコンポーネントを読み込んで行きましょう。
ここでは、マテリアルデザインに対応した各要素が使えるようになるPaper Elementsコンポーネントを
試してみることにします。
インストールは次の1コマンドだけです。

```
$ bower install --save Polymer/paper-elements
```

インストールしたら、早速index.htmlを編集し、試してみましょう。

```
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <script src="bower_components/webcomponentsjs/webcomponents.min.js"></script>
    <link rel="import" href="bower_components/paper-elements/paper-elements.html">
  </head>
  <body>
    <h1>Try Polymer!</h1>
    <p>マテリアルデザインのフォームを試してみよう！</p>
    <paper-input label="お名前をどうぞ"></paper-input>
    <paper-button raised>送信ボタン</paper-button>
  </body>
</html>
```

この状態で`http://localhost:8000`にアクセスすることで、
きれいにデザインされたテキストフォームとボタンが見られるはずです。

このように、デザインや動きがカプセル化された、再利用しやすい要素が非常に簡単に取り扱える様になります。

Polymer/paper-elementsのリポジトリを見ればお気づきになるかもしれませんが、
コンポーネントはある程度まとめてインストール出来るだけでなく
要素毎の個別にインストールが出来るように作られているのも魅力的ではないでしょうか。

Polymer on Rails
----

さて、この便利なPolymerをrailsで使うにはどうすれば良いでしょうか？
選択肢は3つあります。Bowerをそのまま使う、polymer-rails というgemを使う、またはbower-railsを使うです。

このうち、著者はbower-railsの使用を推奨します。

まず、Bowerを直接使用するのは、RailsのAssetPipelineを考慮すると、あまりオススメはできません。

polymer-railsは
インストールが簡単
asset pipeline に対応
自作コンポーネントが作りやすい
外部コンポーネントの読み込みは gem 化待ち

emceeは
コレ自体のインストールは簡単だけど、 polymer のインストールが別途必要
asset pipeline に対応
自作コンポーネントは作れる
外部コンポーネントは bower で管理
その為に bower-rails もインストールしよう

polymer-rails を使う
bower を使う
bower-rails を使う
の３つの選択肢があり、著者は bower-rails を推奨する

参考リンク
http://stackoverflow.com/questions/26884022/google-polymer-with-rails-4
http://rubygems.org/gems/polymer-rails
http://rubygems.org/gems/emcee
http://joshhuckabee.com/getting-started-polymer-ruby-rails
https://coderwall.com/p/99oshq/how-to-integrate-webcomponents-and-other-assets-into-rails-4
