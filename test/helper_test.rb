require 'minitest/autorun'
require 'minitest/reporters'
require 'crossriverbank'
require 'json'
require 'vcr'
require_relative 'test_it'

module CrossRiverBank
  module Test
    class << self
      attr_accessor :logger

      def wait_for(&condition)
        raise ArgumentError, 'You must pass either an argument or a block to `wait_for`.' unless block_given?

        Timeout::timeout(60 * 160) {# wait for 20 mins
          until condition.call
            sleep(5)
          end
        }
      end

      def url
        return @url unless @url.nil?
        @url = ENV['PROCESSING_URL'] or 'https://api.sandbox.crb.finixpayments.com'
      end

      def admin_username
        return @admin_username unless @admin_username.nil?
        @admin_username = ENV['CROSSRIVERBANK_ADMIN_USERNAME']
      end

      def admin_password
        return @admin_password unless @admin_password.nil?
        @admin_password = ENV['CROSSRIVERBANK_ADMIN_PASSWORD']
      end

    end
  end
end
