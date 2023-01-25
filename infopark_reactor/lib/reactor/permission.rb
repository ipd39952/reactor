require "reactor/session"
require "reactor/cache/permission"
require "reactor/cache/user"

module Reactor
  # This module adds #permission method to obj that act as a gateway for permission checking,
  # see documentation for [Permission::PermissionProxy] for more details.
  # @see [Permission::PermissionProxy]
  #
  # Including this module also alters typical ActiveRecord call chain, so that it becomes:
  # 1. permission checking
  # 2. validations (if [Reactor::Validations] is included)
  # 3. callbacks (before_*, around_*, after_*)
  #
  # Therefore if the user lacks permissions no futher actions are executed.
  module Permission
    module Base
      # @see [PermissionProxy]
      def permission
        @permission ||= PermissionProxy.new(self)
      end

      # Wraps around Reactor::Persistence::Base#release! and ensures
      # that current user has required permissions to release the object
      # @raise [Reactor::NotPermitted] user lacks neccessary permission
      def release!(*args)
        ensure_permission_granted(:release)
        super
      end

      # Wraps around Reactor::Persistence::Base#take! and ensures
      # that current user has required permissions to take the object
      # @raise [Reactor::NotPermitted] user lacks neccessary permission
      def take!(*args)
        ensure_permission_granted(:take)
        super
      end

      # Wraps around Reactor::Persistence::Base#revert! and ensures
      # that current user has required permissions to revert the object
      # @raise [Reactor::NotPermitted] user lacks neccessary permission
      def revert!(*args)
        ensure_permission_granted(:revert)
        super
      end

      # Wraps around Reactor::Persistence::Base#edit! and ensures
      # that current user has required permissions to edit the object
      # @raise [Reactor::NotPermitted] user lacks neccessary permission
      def edit!(*args)
        ensure_permission_granted(:edit)
        super
      end

      # Wraps around ActiveRecord::Persistence#save and ensures
      # that current user has required permissions to save the object
      # @raise [Reactor::NotPermitted] user lacks neccessary permission
      def save
        if persisted?
          ensure_permission_granted(:write)
        else
          ensure_create_permission_granted(parent_obj_id)
        end
        super
      rescue Reactor::NotPermitted
        false
      end

      # Wraps around ActiveRecord::Persistence#save! and ensures
      # that current user has required permissions to save the object
      # @raise [Reactor::NotPermitted] user lacks neccessary permission
      def save!
        if persisted?
          ensure_permission_granted(:write)
        else
          ensure_create_permission_granted(parent_obj_id)
        end
        super
      end

      # Wraps around Reactor::Persistence::Base#resolve_refs! and ensures
      # that current user has required permissions to call resolve refs on the object
      # @raise [Reactor::NotPermitted] user lacks neccessary permission
      def resolve_refs!
        ensure_permission_granted(:write)
        super
      end

      private

      def ensure_permission_granted(type)
        unless permission.send("#{type}?")
          raise Reactor::NotPermitted, "#{path} lacks neccessary permissions for #{type}"
        end

        true
      end

      def ensure_create_permission_granted(obj_id)
        unless RailsConnector::AbstractObj.exists?(obj_id)
          raise "Permission check for object with id=#{obj_id.inspect} which does not exist"
        end
        unless RailsConnector::AbstractObj.find(obj_id).permission.create_children?
          raise Reactor::NotPermitted, "Obj lacks neccessary permissions for creation"
        end

        true
      end
    end

    # This class acts as a proxy to underlying permission checking classes.
    # There are three possible cases for each permission type (live, read, write, root, create_children):
    # 1. Given user is SuperUser - all permissions granted
    # 2. Given user has the permission
    # 3. Given user doesn't have the permission
    class PermissionProxy
      def initialize(obj) #:nodoc:
        @obj = obj
        @cache = Reactor::Cache::Permission.instance
        @lookup = PermissionLookup.new(obj)
      end

      # Returns true if given user (or current user, if none given) has 'live' permission
      def live?(user = nil)
        granted?(user, :live)
      end

      # Returns true if given user (or current user, if none given) has 'read' permission
      def read?(user = nil)
        granted?(user, :root) || granted?(user, :read)
      end

      # Returns true if given user (or current user, if none given) has 'write' permission
      def write?(user = nil)
        granted?(user, :root) || granted?(user, :write)
      end

      # Returns true if given user (or current user, if none given) has 'root' permission
      def root?(user = nil)
        granted?(user, :root)
      end

      # Returns true if given user (or current user, if none given) has 'create_children' permission
      def create_children?(user = nil)
        granted?(user, :root) || granted?(user, :create_children)
      end

      # @see #root?
      def delete?(user = nil)
        root?(user)
      end

      # @see #write?
      def take?(user = nil)
        write?(user)
      end

      # @see #write?
      def revert?(user = nil)
        write?(user)
      end

      # @see #write?
      def edit?(user = nil)
        write?(user)
      end

      # Returns true if given user has permissions required to release an object (the exact
      # permissions depend on the state of the object)
      def release?(user = nil)
        if !has_workflow?
          # NOTE: order matters for speed
          write?(user) || root?(user)
        else
          # this is slow
          root?(user) || (has_workflow_api? && obj.workflow.release?)
        end
      end

      # Setter to overwrite the current groups for the given +permission+ with the
      # given +groups+.
      def set(permission, groups)
        identifier = identifier(permission)

        groups = [groups] if groups.is_a?(::String)
        crul_obj.permission_set(identifier, groups)
      end

      # Grants the given +groups+ the given +permission+, without effecting
      # already existing groups.
      def grant(permission, groups)
        identifier = identifier(permission)

        groups = [groups] if groups.is_a?(::String)
        crul_obj.permission_grant(identifier, groups)
      end

      # Takes away the given +permission+ from the given +groups+, without effecting
      # already existing groups.
      def revoke(permission, groups)
        identifier = identifier(permission)

        groups = [groups] if groups.is_a?(::String)
        crul_obj.permission_revoke(identifier, groups)
      end

      # Takes away the given +permission+ from all groups currently set.
      def clear(permission)
        identifier = identifier(permission)

        crul_obj.permission_clear(identifier)
      end

      protected

      attr_reader :cache, :obj, :lookup

      def crul_obj
        obj.send(:crul_obj)
      end

      def default_user
        Reactor::Session.instance.user_name || Reactor::Configuration.xml_access[:username]
      end

      def granted?(user, permission)
        user ||= default_user
        cache.lookup(user, "#{obj.id}:#{permission}") do
          lookup.superuser?(user) || lookup.send("#{permission}?", user)
        end
      rescue Reactor::Cm::MissingCredentials
        raise
      rescue StandardError => e
        Rails.logger.error("Error looking up #{user}'s permission for #{permission} operation on #{obj.path} :\n#{e.message}")
        false
      end

      # A table with all available permissions and their identifier.
      def self.permissions
        @permissions ||= {
          read: "permissionRead",
          root: "permissionRoot",
          live: "permissionLiveServerRead",
          write: "permissionWrite",
          create_children: "permissionCreateChildren"
        }
      end

      def identifier(permission)
        self.class.permissions[permission]
      end

      # NOTE: this method may lie, when:
      # - object received workflow and the cached state says otherwise
      # - the workflow api is deactivated
      def has_workflow?
        cache.lookup(:any, "#{obj.path}:workflow") do
          obj.workflow_name.present?
        end
      end

      def has_workflow_api?
        obj.class < Reactor::Workflow::Base
      end
    end

    class PermissionLookup
      def initialize(obj)
        @obj = obj
        @cache = Reactor::Cache::User.instance
      end

      Reactor::Permission::PermissionProxy.permissions.keys.each do |permission|
        define_method "#{permission}?" do |user|
          user_in_groups(user, obj.permissions.send(permission))
        end
      end

      def superuser?(user)
        cache.get(user).superuser?
      end

      def groups(user)
        cache.get(user).groups
      end

      protected

      attr_reader :cache, :obj

      def user_in_groups(user, groups)
        groups(user).detect { |user_group| groups.include?(user_group) } != nil
      end
    end
  end
end
