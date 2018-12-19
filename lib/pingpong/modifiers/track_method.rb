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

  class InsertTrack < PPTreeRewriter

    def on_def(node)
      expression = node.children[2].loc.expression

      code = <<~PP
      method(__method__).parameters.each do |_, arg|
          puts "\#{arg}: \#{binding.local_variable_get(arg)}"
        end
      PP

      @source_rewriter.transaction do
        insert_before(expression, "result = begin\n\s\s")
        insert_before(expression, code)
        insert_after(expression, "\nend\nputs result")
      end
    end

  end

end

rewriter = Parser::InsertTrack.new
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
