require 'app/models/github'
require 'app/models/log_message'
require 'app/models/owner'
require 'app/models/pod'
require 'app/models/pod_version'
require 'app/concerns/git_commit_sha_validator'

module Pod
  module TrunkApp
    class PushJob < Sequel::Model
      self.dataset = :push_jobs

      plugin :timestamps
      plugin :validation_helpers

      many_to_one :commit
      many_to_one :owner
      one_to_many :log_messages, :order => Sequel.asc(:created_at)

      def self.succeeded
        where(:succeeded => true)
      end
      
      def self.failed
        where(:succeeded => false)
      end
      
      def self.in_progress
        where(:succeeded => nil)
      end
    
      # TODO If a commit hasn't been "pushed" (pushed is nil), this one is in_progress.
      #
      def in_progress?
        succeeded.nil?
      end
      
      # TODO If a commit has been successfully pushed (is true).
      #
      def completed?
        !succeeded.nil? && succeeded
      end

      # TODO If a commit hasn't been successfully pushed (is false).
      #
      def failed?
        !succeeded.nil? && !succeeded
      end

      def duration
        ((in_progress? ? Time.now : updated_at) - created_at).ceil
      end
      
      def commit_sha
        commit.sha
      end
      
      def specification_data
        commit.specification_data
      end

      # TODO Refactor this whole method.
      #
      def submit_specification_data!
        perform_work 'Submitting specification data to GitHub' do
          message = "[Add] #{pod_version.pod.name} #{pod_version.name}"
          commit_sha =  self.class.github.create_new_commit(pod_version.destination_path,
                                                            specification_data,
                                                            message,
                                                            owner.name,
                                                            owner.email)
          # TODO What to do here? Create a new commit and set it to pushed?
          update(:commit_sha => commit_sha, :succeeded => true)
          # TODO Propagate this differently.
          #
          commit.pod_version.update(:published => true, :published_by_submission_job => self, :commit_sha => commit_sha)
          commit.pod_version.pod.add_owner(owner) if commit.pod_version.pod.owners.empty?
          add_log_message(:message => 'Published.')
        end
      end

      protected

      def validate
        super
        validates_presence :commit_id
        validates_presence :owner_id
      end

      def self.github
        @github ||= GitHub.new(ENV['GH_REPO'], :username => ENV['GH_TOKEN'], :password => 'x-oauth-basic')
      end

      def self.perform_work(&block)
        db.transaction(:savepoint => true, &block)
        return nil
      rescue Object => error
        TRUNK_APP_LOGGER.error "#{error.message}\n\t\t#{error.backtrace.join("\n\t\t")}"
        return error
      end

      def perform_work(message, &block)
        add_log_message(:message => message)
        if error = self.class.perform_work(&block)
          update(:succeeded => false)
          add_log_message(:message => "Failed with error: #{error.message}")
          raise error
        end
      end
    end
  end
end

