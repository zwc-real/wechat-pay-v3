require 'restclient'
require "wechat_pay_v3/version"
require "wechat_pay_v3/pay"
require "wechat_pay_v3/sign"

module WechatPayV3
  class Error < StandardError; end
  # Your code goes here...

  class<< self
    attr_accessor :app_id, :mch_id, :mch_key, :apiclient_key, :apiclient_serial_no, :platform_cert
  end
end
