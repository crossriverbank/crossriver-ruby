require 'timeout'
require 'logger'
require_relative 'helper_test'
require 'byebug'

module CrossRiverBank

  module Test
    class TestIt < Minitest::Test

      TESTS_NOT_USE_CASSETTE = 'test_create_settlement', 'test_refresh_resource', 'test_dispute', 'test_count_in_pagination'

      def initialize(name)
        super name
        @logger = CrossRiverBank::Test.logger
        if @logger.nil?
          @logger = Logger.new(STDOUT)
          @logger.level = Logger::INFO
        end
      end


      def run(*args)
        if TESTS_NOT_USE_CASSETTE.include? self.name
          VCR.turn_off!
          return super
        end

        VCR.turn_on!
        VCR.use_cassette self.name do
          super
        end
      end

      def setup
        CrossRiverBank.configure :root_url => CrossRiverBank::Test.url, :user=>CrossRiverBank::Test.admin_username, :password => CrossRiverBank::Test.admin_password
        @admin = CrossRiverBank::User.new(:enabled => 'true', :role => 'ROLE_PLATFORM').save
        @logger.debug @admin
        refute_nil @admin.id

        CrossRiverBank.configure(:user => @admin.id, :password => @admin.password)

        @entity = File.read File.expand_path('fixtures/entity.json', File.dirname(__FILE__))
        @application = JSON.parse(@entity)
        @application = @admin.create_application(@application)
        @logger.debug @application
        refute_nil @application.id

        @application.processing_enabled = true
        @application.settlement_enabled = true
        @application = @application.save
        @logger.debug @application
        refute_nil @application.id

        @partner_user = @application.create_partner_user(:enabled => 'true')
        @logger.debug @partner_user
        refute_nil @partner_user.id

        @dummy_processor = JSON.parse(File.read(File.expand_path('fixtures/dummy.json', File.dirname(__FILE__))))
        @dummy_processor = @application.create_processor(@dummy_processor)
        @logger.debug @dummy_processor
        refute_nil @dummy_processor.id

        CrossRiverBank.configure(:user => @partner_user.id, :password => @partner_user.password)

        @identity = JSON.parse(@entity)
        @identity = CrossRiverBank::Identity.new(@identity).save
        @logger.debug @identity
        refute_nil @identity.id

        @token = File.read(File.expand_path('fixtures/token.json', File.dirname(__FILE__))).gsub('@identity', @identity.id)
        @token = JSON.parse(@token)
        @token = @application.create_token(@token)
        @logger.debug @token
        refute_nil @token.id

        @payment_card = JSON.parse(File.read(File.expand_path('fixtures/payment_card.json', File.dirname(__FILE__))))
        @payment_card = @identity.create_payment_instrument(@payment_card)
        @logger.debug @payment_card
        refute_nil @payment_card.id

        @bank_account = JSON.parse(File.read File.expand_path('fixtures/bank_account.json', File.dirname(__FILE__)))
        @bank_account = @identity.create_payment_instrument(@bank_account)
        @logger.debug @bank_account
        refute_nil @bank_account.id

        @merchant = @identity.provision_merchant
        @logger.debug @merchant
        refute_nil @merchant.id
      end

      def test_assert_instances
        assert_instance_of CrossRiverBank::User, @admin
        assert_instance_of CrossRiverBank::Pagination, @admin.applications

        assert_instance_of CrossRiverBank::Application, @application
        assert_instance_of CrossRiverBank::User, @partner_user
        assert_instance_of CrossRiverBank::Processor, @dummy_processor

        assert_instance_of CrossRiverBank::Identity, @identity
        assert_instance_of CrossRiverBank::Application, @identity.application
        assert_instance_of CrossRiverBank::Application, @identity.links.application
        assert_instance_of ::String, @identity.application.id

        assert_instance_of CrossRiverBank::Token, @token
        assert_instance_of CrossRiverBank::Merchant, @merchant

        assert_instance_of CrossRiverBank::PaymentCard, @payment_card
        assert_instance_of ::String, @payment_card.identity
        assert_instance_of CrossRiverBank::Identity, @payment_card.links.identity

        assert_instance_of CrossRiverBank::Pagination, CrossRiverBank::Application.fetch
      end

      def test_verify_resources
        [
            @identity,
            @merchant,
            test_create_payment_card_directly,
            test_create_bank_account_directly
        ].each do |entity|
          verify = entity.verify :processor => 'DUMMY_V1'
          @logger.debug verify
          refute_nil verify.id
        end
      end

      def test_refresh_resource
        @admin = @admin.refresh
        refute_nil @admin.id
      end

      def test_create_payment_card_directly
        payment_card = CrossRiverBank::PaymentCard.new JSON.parse(File.read(File.expand_path('fixtures/payment_card.json', File.dirname(__FILE__))))
        payment_card.identity = @identity.id
        payment_card = payment_card.save
        @logger.debug payment_card
        refute_nil payment_card.id
        payment_card
      end

      def test_create_bank_account_directly
        bank_account = CrossRiverBank::BankAccount.new JSON.parse(File.read File.expand_path('fixtures/bank_account.json', File.dirname(__FILE__)))
        bank_account.identity = @identity.id
        bank_account = bank_account.save
        @logger.debug bank_account
        refute_nil bank_account.id
        bank_account
      end

      def test_payment_instruments_retrieval
        payment_card = test_create_payment_card_directly
        bank_account = test_create_bank_account_directly

        identity = CrossRiverBank::Identity.retrieve @identity.id
        @logger.debug identity
        refute_nil identity.id

        identity.payment_instruments.find { |pi| pi.id == payment_card.id } \
      or raise "Identity #{@identity.id} not has instance #{payment_card.id}"

        identity.payment_instruments.find { |pi| pi.id == bank_account.id } \
      or raise "Identity #{@identity.id} not has bank_account #{bank_account.id}"
      end

      def test_create_resource_class
        payment_card = CrossRiverBank::PaymentCard.new JSON.parse(File.read(File.expand_path('fixtures/payment_card.json', File.dirname(__FILE__))))
        payment_card = @identity.create_payment_instrument(payment_card)
        @logger.debug payment_card
        refute_nil payment_card.id
      end

      def test_create_transfer
        debit_transfer = File.read(File.expand_path('fixtures/transfer.json', File.dirname(__FILE__)))
                             .gsub('@source', @payment_card.id)
                             .gsub('@identity', @identity.id)
        debit_transfer = JSON.parse(debit_transfer)
        debit_transfer = CrossRiverBank::Transfer.new(debit_transfer).save
        @logger.debug debit_transfer
        refute_nil debit_transfer.id
        assert_equal 'PENDING', debit_transfer.state
        debit_transfer
      end

      def test_create_authorization(*args)
        authorization = File.read(File.expand_path('fixtures/authorization.json', File.dirname(__FILE__)))
                            .gsub('@source', @payment_card.id)
                            .gsub('@identity', @identity.id)
        authorization = JSON.parse(authorization)

        opts = args.slice(0) || {}
        authorization['amount'] = opts[:amount] if opts.has_key? :amount

        authorization = CrossRiverBank::Authorization.new(authorization).save
        @logger.debug authorization
        assert_equal 'SUCCEEDED', authorization.state
        authorization
      end

      def test_capture_authorization
        authorization = test_create_authorization
        authorization = authorization.capture(:capture_amount => 50, :fee => 10)
        @logger.debug authorization
        refute_nil authorization.id
        assert_equal false, authorization.is_void
      end

      def test_void_authorization
        authorization = test_create_authorization
        authorization = authorization.void
        @logger.debug authorization
        refute_nil authorization.id
        assert_equal true, authorization.is_void
        authorization
      end

      def test_create_webhook
        webhook = CrossRiverBank::Webhook.new(:url => 'https://tools.ietf.org/html/rfc2606#section-3').save
        @logger.debug webhook
        refute_nil webhook.id
      end

      def test_create_settlement
        transfer1 = test_create_transfer
        transfer2 = test_create_transfer

        CrossRiverBank::Test.wait_for {
          @logger.debug 'waiting for `transfers` ready to settle'
          transfer1.refresh.state == 'SUCCEEDED' \
        and transfer2.refresh.state == 'SUCCEEDED' \
        and transfer1.refresh.ready_to_settle_at != nil \
        and transfer2.refresh.ready_to_settle_at != nil
        }

        settlement = @identity.create_settlement(:processor => 'DUMMY_V1', :currency => 'USD')
        @logger.debug settlement
        refute_nil settlement.id
        settlement
      end


      def test_reverse_transfer
        transfer = test_create_transfer
        reverse = transfer.reverse 100
        @logger.debug reverse
        refute_nil reverse.id
        assert_equal 'SUCCEEDED', reverse.state
      end

      def test_find_identity
        identity = CrossRiverBank::Identity.fetch @identity.id
        @logger.debug identity
        refute_nil identity.id

        identity = CrossRiverBank::Identity.find :id => @identity.id
        @logger.debug identity
        refute_nil identity.id

        identity = CrossRiverBank::Identity.retrieve @identity.id
        @logger.debug identity
        refute_nil identity.id
      end

      def test_find_one_identity
        identity = CrossRiverBank::Identity.fetch.first
        assert_instance_of CrossRiverBank::Identity, identity
        @logger.debug identity.id
      end

      def test_create_payment_instrument_token
        payment_instrument_token = CrossRiverBank::PaymentInstrument.new(
            :token => @token.id,
            :type => 'TOKEN',
            :identity => @identity.id).save
        @logger.debug payment_instrument_token
        refute_nil payment_instrument_token.id
        assert_equal payment_instrument_token.identity, @identity.id
      end

      def test_raise_unprocessable_entity
        begin
          authorization = test_void_authorization
          authorization.void
        rescue CrossRiverBank::UnprocessableEntity => ex
          assert_equal 1, ex.total
          assert_equal 422, ex.code

          error = ex.errors[0]
          assert_equal 'UNPROCESSABLE_ENTITY', error.code
          assert_match /Authorization #{authorization.id} has been voided/, error.message
        end
      end

      def assert_fetch_transfers_by_offset(*args, &block)
        transfers = []
        total_transfer = 7
        total_transfer.times { transfers.push test_create_transfer }

        offset = 0; limit = 3
        fetch_transfers = []
        until offset >= total_transfer
          limit = [limit, total_transfer - offset].min
          transfers_at = block.call offset, limit
          fetch_transfers.concat transfers_at
          offset += limit
        end

        assert_equal fetch_transfers.length, transfers.length

        opts = args.slice(0) || {}
        if opts[:eq_transfers]
          # same transfer ids returned
          fetch_transfer_ids = fetch_transfers.map { |t| t.id }
          transfer_ids = transfers.map { |t| t.id }
          assert_equal transfer_ids.sort!.to_s, fetch_transfer_ids.sort!.to_s
        end
      end

      def test_fetch_identities_transfers_by_offset
        assert_fetch_transfers_by_offset(
            :eq_transfers => true,
            &->(offset, limit) { @identity.transfers.fetch :page => {:offset => offset, :limit => limit} }
        )

        assert_fetch_transfers_by_offset(
            :eq_transfers => true,
            &->(offset, limit) { @identity.transfers.fetch :offset => offset, :limit => limit }
        )
      end

      def test_fetch_transfers_by_offset
        assert_fetch_transfers_by_offset { |offset, limit| CrossRiverBank::Transfer.pagination(:page => {:offset => offset, :limit => limit}).fetch }
        assert_fetch_transfers_by_offset { |offset, limit| CrossRiverBank::Transfer.pagination(:offset => offset, :limit => limit).fetch }

        # test with :page in param
        assert_fetch_transfers_by_offset do |offset, limit|
          transfer_pagination = CrossRiverBank::Transfer.pagination :page => {:limit => limit} if transfer_pagination.nil?
          transfer_pagination.fetch :page => {:offset => offset}
        end

        # test without :page in param
        assert_fetch_transfers_by_offset do |offset, limit|
          transfer_pagination = CrossRiverBank::Transfer.pagination :limit => limit if transfer_pagination.nil?
          transfer_pagination.fetch :offset => offset
        end
      end

      def test_fetch_payment_card_by_id
        instance = CrossRiverBank::PaymentCard.retrieve :id => @payment_card.id
        @logger.debug instance
        assert_equal instance.id, @payment_card.id
        assert_instance_of CrossRiverBank::PaymentCard, instance
      end

      def test_fetch_bank_account_by_id
        instance = CrossRiverBank::BankAccount.retrieve :id => @bank_account.id
        @logger.debug instance
        assert_equal instance.id, @bank_account.id
        assert_instance_of CrossRiverBank::BankAccount, instance
      end

      def test_count_in_pagination
        original_count = CrossRiverBank::Authorization.retrieve.count
        test_create_authorization
        assert_equal CrossRiverBank::Authorization.retrieve.count, original_count + 1

        original_count = @identity.authorizations.count; sample_amount = 100
        test_create_authorization :amount => sample_amount
        assert_equal original_count + 1, @identity.authorizations.count

        # count with condition
        original_count = @identity.authorizations.count; count_sample_authorization = 7; limit = 2
        1.upto(count_sample_authorization) do |step| # amount=(1..7)*(sample_amount+1)
          test_create_authorization :amount => step * (sample_amount + 1)
        end

        @identity.authorizations.init! :limit => limit # update :limit => 2 items per page

        assert_equal limit, @identity.authorizations.refresh.items.length
        assert_equal original_count + count_sample_authorization, @identity.authorizations.count

        # this `count` must iterate all `authorizations` to get appropriate item
        assert_equal original_count, @identity.authorizations.count { |auth| auth.amount == sample_amount }
        assert_equal count_sample_authorization, @identity.authorizations.count { |auth| auth.amount > sample_amount }
      end
    end
  end
end
