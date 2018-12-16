require "pingpong/version"

module Pingpong
  class Error < StandardError; end

  module Vernacular::AST::Modifiers
    
    # Extends Ruby syntax to allow build wrapper around method, as in:
    # def_wrap original_method; end
    class WrapInstanceMethods < ASTModifier
      def initialize
        super
        
        # Extend the parser 
        extend_parser(:def_wrap, '')
        

        # Extend the builder by adding a 'some' function that will build
        # wrapper around original method
        extend_builder()

        # Extend the rewriter by adding an 'def_wrap' callback, which will be
        # called when 'def_wrap' node is added to the AST.
        build_rewriter { include WrapInstanceMethodsRewriter }
      end

      module WrapInstanceMethodsRewriter
        def def_wrap(method_node)

          # check is there method with name _<original_method>
          # change the original method to _<original_method>
          # write wrapper around original method

        end
      end
    end
  end
end
