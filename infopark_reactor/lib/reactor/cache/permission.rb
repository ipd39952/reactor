module Reactor
  module Cache
    class Permission
      BACKING_CACHE_EXPIRATION = 5

      def self.instance
        new
      end

      def initialize
        @@backing_storage ||= ActiveSupport::Cache::MemoryStore.new({ size: 1.megabyte })
      end

      def lookup(user, key)
        cache_entry = @@backing_storage.fetch(user.to_s, expires_in: BACKING_CACHE_EXPIRATION.minutes) do
          { key => yield }
        end
        if cache_entry.key?(key)
          cache_entry[key]
        else
          result = yield
          @@backing_storage.write(user.to_s, cache_entry.merge({ key => result }), expires_in: BACKING_CACHE_EXPIRATION.minutes)
          result
        end
      end

      def invalidate(user)
        @@backing_storage.delete(user.to_s)
      end
    end
  end
end
