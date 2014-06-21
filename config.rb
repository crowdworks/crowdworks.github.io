Time.zone = "Tokyo"

activate :livereload

activate :blog do |blog|
  blog.tag_template = "tag.html"
  blog.calendar_template = "calendar.html"
  blog.layout = 'blog_layout'
end

require 'digest/md5'

helpers do
  def gravatar_for(email)
    hash = Digest::MD5.hexdigest(email.chomp.downcase)
    "http://s.gravatar.com/avatar/#{hash}?s=32"
  end
end

activate :syntax, :line_numbers => true

set :haml, { ugly: true }

set :markdown_engine, :redcarpet

set :markdown, :fenced_code_blocks => true, :smartypants => true

page "/feeds.xml", layout: false
page "/sitemap.xml", layout: false

set :css_dir, 'stylesheets'

set :js_dir, 'javascripts'

set :images_dir, 'images'

# Build-specific configuration
configure :build do
  ignore 'images/*.psd'
  ignore 'stylesheets/lib/*'
  ignore 'stylesheets/vendor/*'
  ignore 'javascripts/lib/*'
  ignore 'javascripts/vendor/*'

  # For example, change the Compass output style for deployment
  activate :minify_css

  # Minify Javascript on build
  activate :minify_javascript

  # Enable cache buster
  # activate :cache_buster

  # Use relative URLs
  # activate :relative_assets

  # Compress PNGs after build
  # First: gem install middleman-smusher
  # require "middleman-smusher"
  # activate :smusher

  # Or use a different image path
  # set :http_path, "/Content/images/"
end

activate :deploy do |deploy|
  deploy.method = :git
  deploy.remote = "mumoshu"
  deploy.branch ="gh-pages"
  deploy.build_before = true
end
