# CrowdWorks Engineer Blog

http://engineer.crowdworks.jp/ のレポジトリです。
Middleman + middleman-blogによるブログで、

* Haml
* CoffeeScript
* SCSS
* 各種Middleman拡張

## ローカルで表示確認する方法

```
$ git clone git@github.com:crowdworks/crowdworks.github.io.git
$ cd crowdworks.github.io
$ bundle install
$ bundle exec middleman
# フォアグランドでローカルサーバが起動するので、
# ブラウザ等でアクセスできる
$ open http://localhost:4567/
```

# Acknowledgement

This project is originally based on [middleman-hamlsasscoffee](https://github.com/pixelsonly/middleman-hamlsasscoffee).
Thanks to @pixelsonly for sharing such a great template!
