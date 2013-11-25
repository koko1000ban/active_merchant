# encoding: utf-8

require 'rack/utils'
require 'nkf'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class GmoPgGateway < Gateway

      self.test_url = "https://%s/payment/" # Test urls are different per user
      self.live_url = "https://%s/payment/"

      self.default_currency = 'JPY'
      self.money_format = :cents
      self.supported_countries = ['JP']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :jcb, :diners_club]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.gmo-pg.com/'

      # The name of the gateway
      self.display_name = 'GmoPg'

      @@parameter_name_map = {
        :access_id             => "AccessID",
        :access_pass           => "AccessPass",
        :address_1             => "Address1",
        :address_2             => "Address2",
        :address_3             => "Address3",
        :address_4             => "Address4",
        :address_5             => "Address5",
        :address_6             => "Address6",
        :amount                => "Amount",
        :cancel_amount         => "CancelAmount",
        :cancel_tax            => "CancelTax",
        :card_name             => "CardName",
        :card_no               => "CardNo",
        :card_pass             => "CardPass",
        :card_seq              => "CardSeq",
        :client_field_1        => "ClientField1",
        :client_field_2        => "ClientField2",
        :client_field_3        => "ClientField3",
        :client_field_flg      => "ClientFieldFlag",
        :commodity             => "Commodity",
        :confirm_base_date     => "ConfirmBaseDate",
        :continuance_month     => "ContinuanceMonth",
        :convenience           => "Convenience",
        :create_member         => "CreateMember",
        :currency              => "Currency",
        :customer_kana         => "CustomerKana",
        :customer_name         => "CustomerName",
        :default_flag          => "DefaultFlag",
        :device_category       => "DeviceCategory",
        :docomo_disp_1         => "DocomoDisp1",
        :docomo_disp_2         => "DocomoDisp2",
        :eddy_add_info_1       => "EdyAddInfo1",
        :eddy_add_info_2       => "EdyAddInfo2",
        :expire                => "Expire",
        :first_month_free_flag => "FirstMonthFreeFlag",
        :holder_name           => "HolderName",
        :http_accept           => "HttpAccept",
        :http_user_agent       => "HttpUserAgent",
        :http_ua               => "HttpUserAgent",
        :inquiry_data          => "InquiryData",
        :inquiry_id            => "InquiryID",
        :item_code             => "ItemCode",
        :item_name             => "ItemName",
        :job_cd                => "JobCd",
        :last_month_free_flag  => "LastMonthFreeFlag",
        :locale                => "Locale",
        :md                    => "MD",
        :mail_address          => "MailAddress",
        :member_id             => "MemberID",
        :member_name           => "MemberName",
        :member_no             => "MemberNo",
        :method                => "Method",
        :order_id              => "OrderID",
        :pin                   => "PIN",
        :pa_res                => "PaRes",
        :pay_times             => "PayTimes",
        :pay_type              => "PayType",
        :payment_term_day      => "PaymentTermDay",
        :payment_term_sec      => "PaymentTermSec",
        :receipts_disp_1       => "ReceiptsDisp1",
        :receipts_disp_2       => "ReceiptsDisp2",
        :receipts_disp_3       => "ReceiptsDisp3",
        :receipts_disp_4       => "ReceiptsDisp4",
        :receipts_disp_5       => "ReceiptsDisp5",
        :receipts_disp_6       => "ReceiptsDisp6",
        :receipts_disp_7       => "ReceiptsDisp7",
        :receipts_disp_8       => "ReceiptsDisp8",
        :receipts_disp_9       => "ReceiptsDisp9",
        :receipts_disp_10      => "ReceiptsDisp10",
        :receipts_disp_11      => "ReceiptsDisp11",
        :receipts_disp_12      => "ReceiptsDisp12",
        :receipts_disp_13      => "ReceiptsDisp13",
        :redirect_url          => "RedirectURL",
        :register_disp_1       => "RegisterDisp1",
        :register_disp_2       => "RegisterDisp2",
        :register_disp_3       => "RegisterDisp3",
        :register_disp_4       => "RegisterDisp4",
        :register_disp_5       => "RegisterDisp5",
        :register_disp_6       => "RegisterDisp6",
        :register_disp_7       => "RegisterDisp7",
        :register_disp_8       => "RegisterDisp8",
        :reserve_no            => "ReserveNo",
        :ret_url               => "RetURL",
        :security_code         => "SecurityCode",
        :seq_mode              => "SeqMode",
        :service_name          => "ServiceName",
        :service_tel           => "ServiceTel",
        :shop_id               => "ShopID",
        :shop_mail_address     => "ShopMailAddress",
        :shop_pass             => "ShopPass",
        :site_id               => "SiteID",
        :site_pass             => "SitePass",
        :suica_add_info_1      => "SuicaAddInfo1",
        :suica_add_info_2      => "SuicaAddInfo2",
        :suica_add_info_3      => "SuicaAddInfo3",
        :suica_add_info_4      => "SuicaAddInfo4",
        :tax                   => "Tax",
        :td_flag               => "TdFlag",
        :td_tenant_name        => "TdTenantName",
        :tel_no                => "TelNo",
        :token                 => "Token"
      }

      def initialize(options = {})
        requires!(options, :login, :password, :host)

        host = options[:host]
        @shop_id = options[:login]
        @shop_password = options[:password]

        self.test_url = self.test_url % host

        super
      end

      def authorize(money, credit_card, options = {})
        raise NotImplementedError.new
      end

      def capture(money, credit_card, options = {})
        raise NotImplementedError.new
      end

      def purchase(money, creditcard, options = {})
        requires!(options, :order_id)

        MultiResponse.run do |r|
          r.process {  fetch_transaction_key_and_pass(money, options) }
          r.process {  execute_purchase(creditcard, access_identification_from_response(r), options) }
        end
      end

      def fetch_transaction_key_and_pass(money, options = {})
        commit(:post, 'EntryTran.idPass', {
          shop_id: @shop_id,
          shop_pass: @shop_password,
          order_id: options[:order_id],
          job_cd: 'CAPTURE',
          amount: money
          }, options)
      end

      def execute_purchase(creditcard, access_identification, options = {})
        post = {}
        post[:order_id] = options[:order_id]
        add_creditcard(post, creditcard)

        commit(:post, 'ExecTran.idPass', post, options)
      end

      private

      def add_creditcard(post, creditcard)
        post[:card_no] = creditcard.number
        post[:expire] = "%02d%02d" % [creditcard.year % 2000, creditcard.month] # YYMM
        post[:method] = 1
        post[:pay_times] = 1
        post
      end

      def access_identification_from_response(response)
        return unless response.success?

        {access_id: response.params['AccessID'], access_pass: response.params['AccessPass']}
      end

      def post_data(params)
        return nil unless params

        params.map do |key, value|
          next if value.blank?

          key = @@parameter_name_map[key.to_sym] rescue key
          if value.is_a?(Hash)
            h = {}
            value.each do |k, v|
              h["#{key}[#{k}]"] = v unless v.blank?
            end
            post_data(h)
          else
            "#{key}=#{CGI.escape(value.to_s)}"
          end
        end.compact.join("&")
      end

      def parse(body)
        response = Rack::Utils.parse_nested_query(body)
        Hash[response.map { |k,v| [k, NKF.nkf('-w',v)] }]
      end

      def commit(method, url, parameters=nil, options = {})
        raw_response = response = nil
        success = false
        base_url = (test? ? test_url : live_url)
        begin
          raw_response = ssl_request(method, base_url + url, post_data(parameters), headers)
          response = parse(raw_response)
          success = !response.key?("ErrCode")
        rescue ResponseError => e
          raw_response = e.response.body
          response = response_error(raw_response)
        end

        Response.new(
            success,
            success ? "OK" : "code:#{response['ErrCode']}, info:#{response['ErrInfo']}",
            response,
            authorization: authorization_from(response),
            test: test?
        )
      end

      def authorization_from(response)
        if response.key?("AccessID")
          response["AccessID"]
        elsif response.key?("TranID")
          response["TranID"]
        end
      end

      def headers
        @@ua ||= JSON.dump(
          :bindings_version => ActiveMerchant::VERSION,
          :lang => 'ruby',
          :lang_version => "#{RUBY_VERSION} p#{RUBY_PATCHLEVEL} (#{RUBY_RELEASE_DATE})",
          :platform => RUBY_PLATFORM,
          :publisher => 'active_merchant'
        )

        {
          "User-Agent" => "ActiveMerchantBindings/#{ActiveMerchant::VERSION}"
        }
      end

    end
  end
end

