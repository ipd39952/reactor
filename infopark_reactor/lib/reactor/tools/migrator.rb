require "reactor/tools/versioner"

module Reactor
  # Class responsible for running a single migration, a helper for Migrator
  class MigrationProxy
    def initialize(versioner, name, version, direction, filename)
      @versioner = versioner
      @name = name
      @version = version
      @filename = filename
      @direction = direction
    end

    def load_migration
      load @filename
    end

    def run
      return down if @direction.to_sym == :down

      up
    end

    def up
      if @versioner.applied?(@version)
        puts "Migrating up: #{@name} (#{@filename}) already applied, skipping"
        true
      else
        result = class_name.send(:up) and @versioner.add(@version)
        if result
          class_name.contained.each do |version|
            puts "#{class_name} contains migration #{version}"
            # @versioner.add(version) # not neccesary!
          end
        end
        result
      end
    end

    def down
      result = class_name.send(:down) and @versioner.remove(@version)
      if result
        class_name.contained.each do |version|
          puts "#{class_name} contains migration #{version}"
          @versioner.remove(version)
        end
      end
      result
    end

    def class_name
      Kernel.const_get(@name)
    end

    attr_reader :name, :version, :filename
  end

  # Migrator is responsible for running migrations.
  #
  # <b>You should not use this class directly! Use rake cm:migrate instead.</b>
  #
  # Migrating to a specific version is possible by specifing VERSION environment
  # variable: rake cm:migrate VERSION=0
  # Depending on your current version migrations will be run up
  # (target version > current version) or down (target version < current version)
  #
  # MIND THE FACT, that you land at the version <i>nearest</i> to target_version
  # (possibly target version itself)
  class Migrator
    # Constructor takes two parameters migrations_path (relative path of migration files)
    # and target_version (an integer or nil).
    #
    # Used by a rake task.
    def initialize(migrations_path, target_version = nil)
      @migrations_path = migrations_path
      @target_version = target_version.to_i unless target_version.nil?
      @target_version = 99_999_999_999_999 if target_version.nil?
      @versioner = Versioner.instance
    end

    # Runs the migrations in proper direction (up or down)
    # Ouputs current version when done
    def migrate
      return up if @target_version.to_i > current_version.to_i

      down
    end

    def up
      rem_migrations = migrations.reject do |version, _name, _file|
        version.to_i > @target_version.to_i or applied?(version)
      end
      run(rem_migrations, :up)
    end

    def down
      rem_migrations = migrations.reject do |version, _name, _file|
        version.to_i <= @target_version.to_i or !applied?(version)
      end
      run(rem_migrations.reverse, :down)
    end

    def migrations
      Dir["#{@migrations_path}/[0-9]*_*.rb"].sort.collect do |file|
        version, name = file.scan(/([0-9]+)_([_a-z0-9]*).rb/).first
        [version, name, file]
      end
    end

    def applied?(version)
      @versioner.applied?(version)
    end

    def current_version
      @versioner.current_version
    end

    def run(rem_migrations, direction)
      begin
        rem_migrations.each do |version, name, file|
          migration = MigrationProxy.new(@versioner, name.camelize, version, direction, file)
          puts "Migrating #{direction}: #{migration.name} (#{migration.filename})"
          migration.load_migration and migration.run or raise "Migrating #{direction}: #{migration.name} (#{migration.filename}) failed"
        end
      ensure
        puts "At version: " + @versioner.current_version.to_s
        puts "WARNING: Could not store applied migrations!" unless @versioner.store
      end
    end
  end
end
