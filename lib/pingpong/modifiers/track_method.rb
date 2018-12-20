# frozen_string_literals: true

require 'astrolabe/builder'
require 'parser/current'
require 'unparser'

# TODO: lib/vernacular/ast.rb
# we can set the project file path to prevent other then project files to be compiled

module Parser

  class PPTreeRewriter < TreeRewriter
    # fix TreeRewriter#rewrite method to avoid passing ast parameter
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

module Vernacular

  module Modifiers
    # Extend Ruby syntax to match ~def...~end
    class TrackMethod < RegexModifier

      PATTERN = /~def\s+.+?~end/m

      def initialize
        super(PATTERN)
      end

      def modify(source)
        source.sub(PATTERN) do |code|
          code.sub!('~def', 'def').sub!('~end', 'end')
          parse_source(code)
        end
      end

      private

      def parse_source(source)
        buffer = Parser::Source::Buffer.new('(example)')
        buffer.source = source

        Parser::InsertTrack.new.rewrite(buffer)
      end

    end

  end

end
