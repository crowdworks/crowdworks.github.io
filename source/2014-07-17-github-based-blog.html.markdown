---
title: GitHubベースで効率的にブログを運用する方法
date: 2014-07-17 12:51 JST
tags:
---

こんにちは、クラウドワークスの九岡です。

このブログはGitHubとMiddleman、その他にHaml・SCSS・Markdownなどを使って執筆・運営されています。

READMORE

# Middleman

静的サイトジェネレータ。middleman-blogというプラグインを使うことで、ブログを運用することもできます。
これが大変便利で、記事の執筆をHamlやらMarkdownやら、Middlemanが対応しているあらゆるフォーマットで行うことができつつ、
公開に伴う承認フローをGitHubのプルリクエストで回すことができます。記事の取り下げも最近GitHubに追加されたプルリクエストのRevert機能で一発です。

# ワークフロー

* git cloneする
* `bundle exec middleman`でテストサーバを起動する
* ブラウザで`http://localhost:4567/`にアクセスする
* `bundle exec middleman article 英語タイトル`で新規記事を作成する
  * 九岡はAtomの[Run Commandパッケージ](https://github.com/kylewlacy/run-command)を使って、Atom内で完結させています
* ブラウザ上で記事ページを開く(新規記事はMiddlemanが自動的にロードしてくれています！)
* 記事を変更するとブラウザ上でも変更点が自動的にリロードされる
* 書き終わったらgit push・hub pull-request
* マージされたらWerckerで自動的に公開
