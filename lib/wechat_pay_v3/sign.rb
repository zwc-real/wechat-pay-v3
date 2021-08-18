# frozen_string_literal: true

require 'openssl'
require 'base64'
require 'securerandom'

module WechatPayV3
  class Sign
    attr_accessor :app_id, :mch_id, :mch_key, :apiclient_key, :apiclient_serial_no, :platform_cert

    def initialize
      @app_id = WechatPayV3.app_id
      @mch_id = WechatPayV3.mch_id
      @mch_key = WechatPayV3.mch_key

      @apiclient_key = WechatPayV3.apiclient_key
      @apiclient_serial_no = WechatPayV3.apiclient_serial_no
      @platform_cert = WechatPayV3.platform_cert
    end

    def generate_js_payment_params(prepay_id)
      timestamp = Time.now.to_i.to_s
      noncestr = SecureRandom.hex
      string = build_paysign_string(app_id, timestamp, noncestr, prepay_id)

      {
        timeStamp: timestamp,
        nonceStr: noncestr,
        package: "prepay_id=#{prepay_id}",
        paySign: sign_string(string),
        signType: 'RSA'
      }.transform_keys(&:to_s)
    end

    # authorization token
    def build_authorization_header(method, url, json_body)
      timestamp = Time.now.to_i
      nonce_str = SecureRandom.hex
      string = build_string(method, url, timestamp, nonce_str, json_body)
      p string
      signature = sign_string(string)

      params = {
        mchid: @mch_id,
        nonce_str: nonce_str,
        serial_no: apiclient_serial_no,
        signature: signature,
        timestamp: timestamp
      }

      params_string = params.transform_keys(&:to_s).map { |key, value| "#{key}=\"#{value}\"" }.join(',')

      "WECHATPAY2-SHA256-RSA2048 #{params_string}"
    end

    def sign_string(string)
      result = @apiclient_key.sign('SHA256', string) # apiclient private key SHA256-RSA2048 signature
      Base64.strict_encode64(result) # Base64
    end

    # api v3 key decrypt
    # https://pay.weixin.qq.com/wiki/doc/apiv3/wechatpay/wechatpay4_2.shtml
    def decrypt_the_encrypt_params(associated_data:, nonce:, ciphertext:)
      # https://contest-server.cs.uchicago.edu/ref/ruby_2_3_1_stdlib/libdoc/openssl/rdoc/OpenSSL/Cipher.html
      tag_length = 16
      decipher = OpenSSL::Cipher.new('aes-256-gcm').decrypt
      decipher.key = mch_key
      decipher.iv = nonce
      signature = Base64.strict_decode64(ciphertext)
      length = signature.length
      real_signature = signature.slice(0, length - tag_length)
      tag = signature.slice(length - tag_length, length)
      decipher.auth_tag = tag
      decipher.auth_data = associated_data
      decipher.update(real_signature)
    end

    def notification_from_wechat?(timestamp, noncestr, json_body, signature)
      string = build_callback_string(timestamp, noncestr, json_body)
      decoded_signature = Base64.strict_decode64(signature)
      platform_cert.public_key.verify('SHA256', decoded_signature, string)
    rescue StandardError => e
      p "wechat signature verify failed. #{e.inspect}"
      false
    end

    private

    def build_string(method, url, timestamp, noncestr, body)
      "#{method}\n#{url}\n#{timestamp}\n#{noncestr}\n#{body}\n"
    end

    def build_paysign_string(appid, timestamp, noncestr, prepayid)
      "#{appid}\n#{timestamp}\n#{noncestr}\nprepay_id=#{prepayid}\n"
    end

    def build_callback_string(timestamp, noncestr, body)
      "#{timestamp}\n#{noncestr}\n#{body}\n"
    end
  end
end
