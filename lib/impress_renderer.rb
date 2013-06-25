require 'redcarpet'
require 'nokogiri'
require 'hexp/h'

class ImpressRenderer < Redcarpet::Render::HTML
  attr_accessor :dest, :transition_duration

  @attrs = []
  @current = 0
  @author, @head, @title = nil

  def init_with_attrs _attrs, _opts
    @attrs = _attrs
    @current = 0
    @opts = _opts
    @counters = {}
  end

  def author= author
    @author = "<meta name=\"author\" content=\"#{author}\">"
  end

  def head= head
    @head = head
  end

  def title= title
    @title = "<title>#{title}</title>"
  end

  def render_attrs(hsh)
    "class='step #{hsh.delete('class')}' "+
    hsh.map do |k,v|
      if v =~ /([\+\-])(\d+)/
        @counters[k] ||= 0
        if $1 == ?+
          @counters[k] += $2.to_i
        else
          @counters[k] -= $2.to_i
        end
        "#{k}='#{@counters[k]}'"
      else
        "#{k}='#{v}'"
      end
    end.join(' ')
  end

  def hrule
    # this is how we later inject attributes into pages. what an awful hack.
    @current += 1
    %{</div>
      <div #{render_attrs(@attrs[@current])}>
    }
  end

  def block_code code, lang
    if lang =~ /^dot/
      _, size = lang.split('-')
      file = Tempfile.new(['mdpress','.dot'])
      file << code
      file.close
      "<div class='dot-wrap'>" +
        (Nokogiri(`dot #{file.path} -Tsvg`)/'svg').first.tap{|svg| svg.search('polygon').first.remove; svg['width']=(size||'600')+'px' ; svg.attributes['height'].remove }.to_html +
        "</div>"
    elsif lang == 'notes'
      "<div class='notes' style='display:none;'>#{code}</div>"
    else
      H[:pre, [
          [:code, {class: "prettyprint #{lang}"}, code]
        ]
      ].to_html
    end
  end

  def codespan code
    H[:code, {class: "inline prettyprint"}, code].to_html
  end

  def image link, title, alt
    if File.exist?("images/#{link}")
      `cp images/#{link} #{dest}/#{link}`
    end
    H[:img, {src: link, alt: alt}, title].to_html
  end

  def mathjax
    if @opts[:latex]
      %{
        <script type="text/x-mathjax-config">
          MathJax.Hub.Config({tex2jax: {inlineMath: [['$','$']]}});
        </script>
        <script type="text/javascript"
          src="http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML">
        </script>
      }
    end
  end

  def doc_header
    %{<!DOCTYPE html>
<html>
  <head>
    #{@title}
    <link href="css/reset.css" rel="stylesheet" />
    #{@author}
    <meta charset="utf-8" />
    <meta name="viewport" content="width=1024" />
    <meta name="apple-mobile-web-app-capable" content="yes" />
    <link rel="shortcut icon" href="css/favicon.png" />
    <link rel="apple-touch-icon" href="css/apple-touch-icon.png" />
    <!-- Code Prettifier: -->
<link href="css/highlight.css" type="text/css" rel="stylesheet" />
<script type="text/javascript" src="js/highlight.pack.js"></script>
<script>hljs.initHighlightingOnLoad();</script>
	<script type="text/javascript">
	  var _gaq = _gaq || [];
	  _gaq.push(['_setAccount', 'UA-16178122-1']);
	  _gaq.push(['_trackPageview']);

	  (function() {
	  var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
	  ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
	  var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
	  })();
	</script>
#{mathjax}
    <link href="css/style.css" rel="stylesheet" />
#{@head}
  </head>

  <body>
  <div class="fallback-message">
  <p>Your browser <b>doesn't support the features required</b> by impress.js, so you are presented with a simplified version of this presentation.</p>
  <p>For the best experience please use the latest <b>Chrome</b>, <b>Safari</b> or <b>Firefox</b> browser.</p>
  </div>
    <div id="impress" data-transition-duration="#{transition_duration}">
    <div #{render_attrs(@attrs[0])}>
    }
  end

  def doc_footer
    %{
      </div>
    <script src="js/impress.js"></script>
    <script>impress().init();</script>
  </body>
</html>
    }
  end
end
