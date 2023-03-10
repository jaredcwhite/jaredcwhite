require "bundler/setup"

require "phlexing"
require "serbea"

html = File.read("my_html.html")
puts html, "----"

tag_name = "my-html"

doc = Nokogiri::HTML5.fragment(
  "<#{tag_name}>#{html}</#{tag_name}>"
)

tag = doc.first_element_child

#mark = doc.document.create_element("mark")
#mark.content = "{{{{%= foo %}}}}"

def erb_directive(code, escaped: true)
  "{{{{%=#{"=" unless escaped} #{code} %}}}}"
end

tag.css("*[host-effect]").each do |el|
  directive = el["host-effect"].split("#")[1].split("->")
  if directive[1] == "textContent"
    el.content = erb_directive(directive[0])
  elsif directive[1] == "innerHTML"
    el.content = erb_directive(directive[0], escaped: false)
  else
    el[directive[1]] = erb_directive("hot_module_attribute(#{directive[0]})")
  end

  el["host-effect"] = erb_directive("'#{el["host-effect"]}'") # odd workaround for foo->bar inside attribute
end

tag.css(".foo").each do
  _1["blah"] = "{{{{%= blah %}}}}"
end

tag.css("*[hmod-erb]").each do |el|
  el.inner_html = el.inner_html.gsub("&lt;%", "{{{{%").gsub("%&gt;", "%}}}}")
  el.remove_attribute("hmod-erb")
end

tag.css("*[hmod-serb]").each do |el|
  el.inner_html = erb_directive("serbea(%(#{el.inner_html.gsub(")", "\\)")}))", escaped: false)
  el.remove_attribute("hmod-serb")
end


html = tag.to_html.gsub("{{{{", "<").gsub("}}}}", ">")

puts html, "----"
phlexed = Phlexing::Converter.convert(html, component: false)
puts phlexed

module MyHTML; end

class MyHTML::View < Phlex::HTML
  include Serbea::Helpers

  register_element :my_html

  def initialize(rbcode:)
    @rbcode = rbcode

    unless respond_to?(:template)
      puts "ADDING!!!"
      self.class.class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def template
          #{@rbcode}
        end
      RUBY
    end
  end

  def foo = "Amazing, <em>folks</em>!"

  def blah = 12345

  def jayson = {a: 1, b: "2"}

  def hot_module_attribute(val)
    case val
    when String, Numeric
      val
    else
      val.to_json
    end
  end

  def serbea(code)
    tmpl = Tilt::SerbeaTemplate.new { code }
    tmpl.render(self)
  end
end

puts phlexed

10.times do
  puts "----", MyHTML::View.new(rbcode: phlexed).call
end
