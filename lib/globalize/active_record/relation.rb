module Globalize
  module ActiveRecord
    class Relation < ::ActiveRecord::Relation

      attr_accessor :translations_reload_needed

      class WhereChain < ::ActiveRecord::QueryMethods::WhereChain
        def not(*args)
          if @scope.parse_translated_conditions!(*args)
            @scope.translations_reload_needed = true
            @scope.with_translations_in_this_locale.where.not(*args)
          else
            super
          end
        end
      end

      def where(opts = :chain, *rest)
        if opts == :chain
          WhereChain.new(spawn)
        elsif parse_translated_conditions!(opts, *rest)
          self.translations_reload_needed = true
          super.with_translations_in_this_locale
        else
          super
        end
      end

      def exists?(conditions = :none)
        if parse_translated_conditions!(conditions)
          with_translations_in_this_locale.exists?(conditions)
        else
          super
        end
      end

      %w[ first last take ].each do |method_name|
        eval <<-END_RUBY
          def #{method_name}
            super.tap do |f|
              if translations_reload_needed
                f.translations.reload
                translations_reload_needed = false
              end
            end
          end
        END_RUBY
      end

      def with_translations_in_this_locale
        with_translations(Globalize.locale)
      end

      def parse_translated_conditions!(opts, *rest)
        if opts.is_a?(Hash) && (keys = opts.symbolize_keys.keys & translated_attribute_names).present?
          keys.each do |key|
            opts[translated_column_name(key)] = opts.delete(key) || opts.delete(key.to_s)
          end
        end
      end
    end
  end
end
