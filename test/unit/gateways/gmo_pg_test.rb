require 'test_helper'

class GmoPgTest < Test::Unit::TestCase

  def setup
    @gateway = GmoPgGateway.new(
                 :login => 'login',
                 :password => 'passw0rd',
                 :host => 'foo.mul-pay.jp'
               )

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => '1'
    }
    @access_identification = {
      access_id: 'access_id',
      access_pass: 'access_pass'
    }
  end

  def test_successful_fetch_transaction_key_request
    @gateway.expects(:ssl_request)
      .returns(successful_transaction_key_and_pass_response)

    response = @gateway.fetch_transaction_key_and_pass(@amount, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal "OK", response.message
    assert_equal(
      "9954ee73885805b9f4e70116994d546d",
      response.authorization
    )
  end

  def test_successful_execute_purchase
    @gateway.expects(:ssl_request)
      .returns(successful_purchase_response)

    response = @gateway.execute_purchase(@credit_card, @access_identification, @options)

    assert_instance_of Response, response
    assert_success response
    assert_equal "OK", response.message
    assert_equal(
      "1311251846111111111111191065",
      response.authorization
    )
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request)
      .twice.returns(successful_transaction_key_and_pass_response, successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    # Replace with authorization number from the successful response
    assert_equal '1311251846111111111111191065', response.authorization
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_request)
      .twice.returns(successful_transaction_key_and_pass_response, failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_unsuccessful_fetch_transaction_key_request
    @gateway.expects(:ssl_request).returns(failed_transaction_key_and_pass_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  private

  def successful_transaction_key_and_pass_response
     "AccessID=9954ee73885805b9f4e70116994d546d&AccessPass=f3e921eb86f229ff5c333bcb5aaaf78c"
  end

  def failed_transaction_key_and_pass_response
    "ErrCode=E01|E01|E01|E01|E01|E01&ErrInfo=E01010001|E01020001|E01030002|E01040001|E0105000
1|E01060001"
  end

  # Place raw successful response from gateway here
  def successful_purchase_response
    "ACS=0&OrderID=7&Forward=2a99662&Method=1&PayTimes=&Approve=9040628&TranID=1311251846111111111111191065&TranDate=20131125184619&CheckString=0a2396aebbf2f48350359932005929dd"
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
    "ErrCode=E01|E01|E01|E01|E01|E01&ErrInfo=E01010001|E01020001|E01030002|E01040001|E0105000
1|E01060001"
  end
end
