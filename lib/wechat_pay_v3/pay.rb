# frozen_string_literal: true

require 'json'

module WechatPayV3
  class Pay
    GATEWAY_URL = 'https://api.mch.weixin.qq.com'

    def initialize
      @sign_client = WechatPayV3::Sign.new
    end

    # send coupon to user
    # https://pay.weixin.qq.com/wiki/doc/apiv3/apis/chapter9_1_2.shtml
    def send_coupon(openid, stock_id)
      path = "/v3/marketing/favor/users/#{openid}/coupons"
      method = 'POST'

      out_request_no = Time.now.strftime('%Y%m%d%H%M') + rand.to_s[2..7]
      params = {
        stock_id: stock_id,
        out_request_no: out_request_no,
        appid: @sign_client.app_id,
        stock_creator_mchid: @sign_client.mch_id
      }

      url = path

      payload_json = params.to_json
      res = make_request(
        path: url,
        method: method,
        for_sign: payload_json,
        payload: payload_json
      )
      JSON.parse(res)
    end

    # get coupon stocks
    # https://pay.weixin.qq.com/wiki/doc/apiv3/apis/chapter9_1_4.shtml
    def get_coupon_stocks(params = {})
      path = '/v3/marketing/favor/stocks'
      method = 'GET'

      params = {
        offset: 0,
        limit: 10,
        stock_creator_mchid: @sign_client.mch_id
      }.merge(params)

      query = build_query(params)
      url = "#{path}?#{query}"

      res = make_request(
        path: url,
        method: method,
        extra_headers: {
          'Content-Type' => 'application/x-www-form-urlencoded'
        }
      )
      JSON.parse(res)
    end

    def get_coupon_stock_detail(stock_id)
      path = "/v3/marketing/favor/stocks/#{stock_id}"
      method = 'GET'

      params = {
        stock_creator_mchid: @sign_client.mch_id
      }

      query = build_query(params)
      url = "#{path}?#{query}"

      res = make_request(
        path: url,
        method: method,
        extra_headers: {
          'Content-Type' => 'application/x-www-form-urlencoded'
        }
      )
      res = JSON.parse(res)
      res['code'] == nil ? res : nil
    end

    # get user coupons
    # https://pay.weixin.qq.com/wiki/doc/apiv3/apis/chapter9_1_9.shtml
    def get_user_coupons(openid, params)
      path = "/v3/marketing/favor/users/#{openid}/coupons"
      method = 'GET'

      params = {
        appid: @sign_client.app_id,
        creator_mchid: @sign_client.mch_id
      }.merge(params)

      query = build_query(params)
      url = "#{path}?#{query}"

      res = make_request(
        path: url,
        method: method,
        extra_headers: {
          'Content-Type' => 'application/x-www-form-urlencoded'
        }
      )
      JSON.parse res
    end

    # get user coupon detail
    # https://pay.weixin.qq.com/wiki/doc/apiv3/apis/chapter9_1_6.shtml
    def get_user_coupon_detail(openid, coupon_id)
      path = "/v3/marketing/favor/users/#{openid}/coupons/#{coupon_id}"
      method = 'GET'

      params = {
        appid: @sign_client.app_id
      }

      query = build_query(params)
      url = "#{path}?#{query}"

      res = make_request(
        path: url,
        method: method,
        extra_headers: {
          'Content-Type' => 'application/x-www-form-urlencoded'
        }
      )
      JSON.parse res
    end

    # preorder and return payment attrs
    # https://pay.weixin.qq.com/wiki/doc/apiv3/apis/chapter3_5_1.shtml
    def generate_wechat_payment(company_name, order_no, sum, open_id, sku_info_list, notify_url)
      url = '/v3/pay/transactions/jsapi'
      method = 'POST'

      params = {
        appid: @sign_client.app_id,
        mchid: @sign_client.mch_id,
        description: company_name,
        out_trade_no: order_no.to_s,
        notify_url: notify_url,
        amount: {
          total: (sum * 100).to_i
        },
        payer: {
          openid: open_id
        },
        detail: {
          goods_detail: sku_info_list
        }
      }

      payload_json = params.to_json

      r1 = make_request(
        method: method,
        path: url,
        for_sign: payload_json,
        payload: payload_json
      )
      r1 = begin
        JSON.parse(r1)
      rescue StandardError
        nil
      end

      return if r1.nil?

      prepay_id = r1['prepay_id']

      r2 = @sign_client.generate_js_payment_params(prepay_id)

      { r1: r1, r2: r2 }
    end

    def certs
      path = '/v3/certificates'
      method = 'GET'

      url = path

      res = make_request(
        path: url,
        method: method,
        extra_headers: {
          'Content-Type' => 'application/x-www-form-urlencoded'
        }
      )
      res = JSON.parse(res)
      data = res['data']
      return if data.nil? || !data.is_a?(Array)

      data.collect do |item|
        resource = item['encrypt_certificate']
        cert = @sign_client.decrypt_the_encrypt_params(
          associated_data: resource['associated_data'],
          nonce: resource['nonce'],
          ciphertext: resource['ciphertext']
        )
        {
          effective_time: item['effective_time'],
          expire_time: item['expire_time'],
          serial_no: item['serial_no'],
          certificate: cert
        }
      end
    end

    private

    def build_query(params)
      params.sort.map { |key, value| "#{key}=#{value}" }.join('&')
    end

    def make_request(method:, path:, for_sign: '', payload: {}, extra_headers: {})
      p '[wechat pay v3]======='
      p "[wechat pay v3]path: #{path}"
      p "[wechat pay v3]payload: #{payload}"
      authorization = @sign_client.build_authorization_header(method, path, for_sign)
      headers = {
        'Authorization' => authorization,
        'Content-Type' => 'application/json',
        'Accept-Encoding' => 'gzip'
      }.merge(extra_headers)

      res = RestClient::Request.execute(
        url: "#{GATEWAY_URL}#{path}",
        method: method.downcase,
        payload: payload,
        headers: headers.compact # Remove empty items
      )
      p "[wechat pay v3]response: #{res.body}"
      res
    rescue ::RestClient::ExceptionWithResponse => e
      e.response
    end
  end
end
