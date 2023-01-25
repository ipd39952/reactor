module Reactor
  module Link
    class TemporaryLink
      attr_reader   :url
      attr_accessor :title, :target

      def external?
        raise TypeError, "This link needs to be persisted to gain any meaningful information"
      end

      def internal?
        false
      end

      def initialize(anything)
        link_data = {}

        case anything
        when Hash
          link_data = anything
        when Integer
          link_data[:url] = RailsConnector::AbstractObj.find(anything).path
        else
          link_data[:url] = anything
        end

        self.url = link_data[:url] || link_data[:destination_object]
        self.url = "#{url}?#{link_data[:search]}" if link_data[:search].present?
        self.url = "#{url}##{link_data[:fragment]}" if link_data[:fragment].present?
        self.target = link_data[:target] if link_data.key?(:target)
        self.title  = link_data[:title] if link_data.key?(:title)
      end

      def url=(some_target)
        @url = case some_target
               when RailsConnector::AbstractObj
                 @destination_object = some_target
                 some_target.path
               else
                 some_target
        end
      end

      def destination_object
        @destination_object ||= RailsConnector::AbstractObj.find_by_path(url)
      end

      def id
        nil
      end
    end
  end
end
