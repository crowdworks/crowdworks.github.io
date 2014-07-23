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

activate :syntax

set :haml, { ugly: true }

set :markdown_engine, :redcarpet

set :markdown, :fenced_code_blocks => true, :smartypants => true, with_toc_data: true

helpers do
  # @see https://github.com/vmg/redcarpet/pull/186#issuecomment-22783188
  def table_of_contents(resource)
    # Without the `gsub` part, we get redundant items like
    #  "tags: <tags set in front-matter>"
    content = File.read(resource.source_file).
      gsub(/^(---\s*\n.*?\n?)^(---\s*$\n?)/m,'')
    toc_renderer = Redcarpet::Render::HTML_TOC.new
    # nesting_level is optional
    markdown = Redcarpet::Markdown.new(toc_renderer, nesting_level: 2)
    markdown.render(content)
  end
end

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

  if ENV['MIDDLEMAN_SYNC_BUCKET_NAME'] != nil && ENV['MIDDLEMAN_SYNC_BUCKET_NAME'].size > 0
    set :http_prefix, "/" + ENV['MIDDLEMAN_SYNC_BUCKET_NAME']
  end
end

activate :disqus do |d|
  d.shortname = 'engineer-crowdworks-jp'
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

activate :sync do |sync|
  sync.fog_provider = 'AWS' # Your storage provider
  sync.fog_directory = ENV['MIDDLEMAN_SYNC_BUCKET_NAME'] # Your bucket name
  sync.fog_region = 'ap-northeast-1' # The region your storage bucket is in (eg us-east-1, us-west-1, eu-west-1, ap-southeast-1 )
  sync.aws_access_key_id = ENV['MIDDLEMAN_SYNC_ACCESS_KEY_ID'] # Your Amazon S3 access key
  sync.aws_secret_access_key = ENV['MIDDLEMAN_SYNC_SECRET_ACCESS_KEY'] # Your Amazon S3 access secret
  sync.existing_remote_files = 'keep' # What to do with your existing remote files? ( keep or delete )
  # sync.gzip_compression = false # Automatically replace files with their equivalent gzip compressed version
  # sync.after_build = false # Disable sync to run after Middleman build ( defaults to true )
end
