module Reactor
  module Plans
    module Prepared
      def error(message)
        "#{self.class.name}: #{message}"
      end

      def separate_arguments(*args)
        array_args  = args.select { |a| !a.is_a?(Hash) }
        hash_args   = args.select { |a| a.is_a?(Hash) }.reduce({}, &:merge)
        [array_args, hash_args]
      end
    end
  end
end
