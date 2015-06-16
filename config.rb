require 'rack/lint'

module ::Rack
  class Lint
    def call(env = nil)
      @app.call(env)
    end
  end
end

def present(str)
  str != nil && str != ''
end

sync_prefix = present(ENV['MIDDLEMAN_SYNC_PREFIX']) ? ENV['MIDDLEMAN_SYNC_PREFIX'] : nil
http_prefix = present(ENV['MIDDLEMAN_HTTP_PREFIX']) ? "/#{ENV['MIDDLEMAN_HTTP_PREFIX']}" : nil

Time.zone = "Tokyo"

activate :livereload, host: 'localhost'

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

activate :syntax

activate :gemoji, size: 20, style: 'vertical-align: middle'

set :haml, { ugly: true }

set :markdown_engine, :redcarpet

set :markdown, :fenced_code_blocks => true, :smartypants => true, with_toc_data: true, footnotes: true, tables: true

helpers do
  # @see https://github.com/vmg/redcarpet/pull/186#issuecomment-22783188
  def table_of_contents(resource)
    # Without the `gsub` part, we get redundant items like
    #  "tags: <tags set in front-matter>"
    content = File.read(resource.source_file).
      gsub(/^(---\s*\n.*?\n?)^(---\s*$\n?)/m,'')
    toc_renderer = Redcarpet::Render::HTML_TOC.new(nesting_level: 3)
    # nesting_level is optional
    markdown = Redcarpet::Markdown.new(toc_renderer)
    markdown.render(content)
  end
end

page "/feeds.xml", layout: false
page "/sitemap.xml", layout: false

set :css_dir, 'stylesheets'

set :js_dir, 'javascripts'

set :images_dir, 'images'

#sync_prefix = `git rev-parse --abbrev-ref HEAD`

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

  set :http_prefix, http_prefix if http_prefix != nil
end

activate :deploy do |deploy|
  deploy.method = :git
  deploy.remote = "origin"
  # Projectページの場合は"gh-pages"
  # Organizationページの場合は"master"
  deploy.branch ="master"
  deploy.build_before = true
end

class Dot < Middleman::Extension
  def initialize(app, options_hash={}, &block)
    super
  end

  helpers do
    def dot(&block)
      content_tag('pre', class: 'dot', style: 'display: none;', &block)
      contents = [
        content_tag('svg', width: 800, height: 600) do
          tag('g', transform: 'translate(20, 20)')
        end
      ]
      contents.each do |c|
        concat_content c
      end
      content_for :scripts do
        <<-HTML
          <script>
            var dotElement = document.querySelector(".dot");

            function tryDraw() {
              var graphlibGraph;
              var dotCode = dotElement.textContent;
              try {
                graphlibGraph = graphlibDot.parse(dotCode);
              } catch (e) {
                throw e;
              }

              if (graphlibGraph) {
                var svg = d3.select("svg");
                var renderer = new dagreD3.Renderer();

                // Uncomment the following line to get straight edges
                //renderer.edgeInterpolate('linear');

                // Custom transition function
                function transition(selection) {
                  return selection.transition().duration(500);
                }

                renderer.transition(transition);

                var layout = renderer.run(graphlibGraph, svg.select("g"));
                transition(d3.select("svg"))
                  .attr("width", layout.graph().width + 40)
                  .attr("height", layout.graph().height + 40)
              }
            }
            tryDraw();
          </script>
        HTML
      end
    end
  end
end

::Middleman::Extensions.register(:dot, Dot)

activate :dot

activate :s3_sync do |s3_sync|
  bucket_name = ENV['MIDDLEMAN_SYNC_BUCKET_NAME']
  access_key_id = ENV['MIDDLEMAN_SYNC_ACCESS_KEY_ID']
  secret_access_key = ENV['MIDDLEMAN_SYNC_SECRET_ACCESS_KEY']
  s3_sync.bucket = bucket_name
  s3_sync.region = 'ap-northeast-1'
  s3_sync.aws_access_key_id = access_key_id
  s3_sync.aws_secret_access_key = secret_access_key
  s3_sync.prefix = sync_prefix
  s3_sync.delete = false
end

activate :google_analytics do |ga|
  ga.tracking_id = 'UA-27177676-8'
  ga.domain_name = 'crowdworks.jp'
  ga.development = false
  ga.minify = true
end

activate :ogp do |ogp|
  ogp.namespaces = {
    og: data.ogp.og
  }
  ogp.base_url = 'http://engineer.crowdworks.jp/'
  ogp.blog = true
end
