xml.instruct!
xml.feed "xmlns" => "http://www.w3.org/2005/Atom" do
  site_url = "http://crowdworks.github.io/"
  xml.title "クラウドワークスエンジニアブログ"
  xml.subtitle "Blog subtitle"
  xml.id URI.join(site_url, blog.options.prefix.to_s)
  xml.link "href" => URI.join(site_url, blog.options.prefix.to_s)
  xml.link "href" => URI.join(site_url, current_page.path), "rel" => "self"
  xml.updated(blog.articles.first.date.to_time.iso8601) unless blog.articles.empty?
  xml.author { xml.name "CrowdWorks, Inc." }

  blog.articles[0..5].each do |article|
    xml.entry do
      xml.title article.title
      xml.link "rel" => "alternate", "href" => URI.join(site_url, article.url)
      xml.id URI.join(site_url, article.url)
      xml.published article.date.to_time.iso8601
      xml.updated File.mtime(article.source_file).iso8601
      author =article.data[:author]
      unless author.nil?
        xml.author { xml.name author }
      end
      # xml.summary article.summary, "type" => "html"
      xml.content article.body, "type" => "html"
      xml.summary article.summary(100), "type" => "html"

      logo_href =
        %i| atom logo href |.inject(article.data) { |d, k| d[k] if d.respond_to?(:[]) } ||
          'http://engineer.crowdworks.jp/images/crowdworks-logo.png'

      xml.logo "href" => logo_href
    end
  end
end
