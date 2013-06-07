require 'redcarpet'
require 'nokogiri'
require 'hexp/h'

class ImpressRenderer < Redcarpet::Render::HTML
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
      <div class='step' #{render_attrs(@attrs[@current])}>
    }
  end

  def block_code code, lang
    if lang == 'dot'
      file = Tempfile.new(['mdpress','.dot'])
      file << code
      file.close
      (Nokogiri(`dot #{file.path} -Tsvg`)/'svg').tap{|svg| svg.search('polygon').remove}.to_html
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
#{mathjax}
    <link href="css/style.css" rel="stylesheet" />
#{@head}
  </head>

  <body>
  <div class="fallback-message">
  <p>Your browser <b>doesn't support the features required</b> by impress.js, so you are presented with a simplified version of this presentation.</p>
  <p>For the best experience please use the latest <b>Chrome</b>, <b>Safari</b> or <b>Firefox</b> browser.</p>
  </div>
    <div id="impress">
    <div class='step' #{render_attrs(@attrs[0])}>
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
