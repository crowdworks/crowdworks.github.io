xml.instruct!
xml.urlset "xmlns" => "http://www.sitemaps.org/schemas/sitemap/0.9" do
  sitemap.resources.each do |resource|
    if resource.destination_path =~ /\.html$/
      xml.url do
        xml.loc "http://crowdworks.github.io/#{resource.url}"
      end
      lastmod = resource.data.modified_date.presence || resource.data.date.presence
      xml.lastmod lastmod if lastmod.present?
    end
  end
end
