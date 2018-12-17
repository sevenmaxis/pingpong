# frozen_string_literals: true

require 'astrolabe/builder'
require 'parser/current'
require 'unparser'

#############################
# lib/vernacular/ast.rb
# we can set the project file path to prevent other the project files to be compiled

# fix TreeRewriter#rewrite method to avoid passing ast parameter
module Parser

  class PPTreeRewriter < TreeRewriter

    def rewrite(buffer)
      super(buffer, Parser::CurrentRuby.new.parse(buffer))
    end

  end

  class AddPPMethod < PPTreeRewriter

    # change method name to pp_<original_method_name>
    # add wrapper method as <original_method_name>
    def on_def(node)
      method_name = node.children.first
      method_name_range = node.loc.name

      replace(method_name_range, "pp_#{method_name}")

      rewriter      = ModifyMethodBody.new
      buffer        = Parser::Source::Buffer.new('(example)')
      buffer.source = Unparser.unparse(node)
      wrap_method   = rewriter.rewrite(buffer)

      insert_before(node.loc.expression, "\n")
      insert_before(node.loc.expression, "\n")
      insert_before(node.loc.expression, wrap_method)

      super
    end

  end

  class ModifyMethodBody < PPTreeRewriter

    # change the method body to track the arguments, 
    # call the original method, track the result
    def on_def(node)
      method_name = node.children.first
      body_range = node.children[2].loc.expression

      arguments = node.children[1].children.map do |arg_node|
        arg_node.children.first
      end.join(", ")
      
      method_call = ["pp_#{method_name}", "(", arguments, ")"].join

      code = <<~PP.chomp
        method(__method__).parameters.each do |_, arg|
            puts "\#{arg}: \#{binding.local_variable_get(arg)}"
          end

          result = #{method_call}

          puts result
      PP

      replace(body_range, code)

      super
    end

  end

end

rewriter = Parser::AddPPMethod.new
buffer = Parser::Source::Buffer.new('(example)')
buffer.source = <<~RUBY
  def test(x, y)
    puts x
    puts y
  end
RUBY
puts rewriter.rewrite(buffer)

def parse_source(source)
  buffer = Parser::Source::Buffer.new('(string)')
  buffer.source = source

  ast_builder = Astrolabe::Builder.new
  parser = Parser::CurrentRuby.new(ast_builder)

  parser.parse(buffer)
end

module Vernacular
  module Modifiers
    # Extend Ruby syntax to match ~def...~end
    class TrackMethod < RegexModifier

      include ParseSource

      def initialize
        super(/~def\s+.+~end/m) 
      end

      # We have to parse the source, build ast, rewrite code,
      # write back to source
      def modify(source)
        source.gsub(/~def/, 'def')
        source.gsub(/~end/, 'end')

        parse_source(source)
      end
    end
  end
end
