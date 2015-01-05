---
title: Polymer で Rails アプリに絵文字ボタンを！（２）公開コンポーネントの活かし方
date: 2015-01-15 11:00 JST
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

Web Components は未来技術ですが、Polymer の活躍によって、もしかしたら実践可能な技術に
なるかもしれません。
Polymer は Web Components を簡単かつ柔軟に試せるように google が開発したラッパーライブラリです。

本記事は次の３回に分けて連載する
Polymer の説明と Rails で使う場合の話
提供されているコンポーネントをカスタマイズする話
実践編として、自分なりのコンポーネントを実装する話

第１回では読み込みをした。
本記事では、自作のエレメントの作り方について解説します。

自作コンポーネントの作り方
----

Polymerを使用すると、まるでDOM要素のような自作の要素を作ることが出来ます。
さらに、自作の要素を作る際に、Polymerを使うことで双方向データバインディングや
その他の便利な機能を使うことが出来ます。

新しいエレメントを作るには、次の２ステップで始められます。

1. Polymer core をロードします
2. 新しい要素名を `<polymer-element>` を使って宣言します。


