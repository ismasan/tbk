module Webpay
  class Payment
    VALIDATION_PATH = "/cgi-bin/bp_validacion.cgi"
    PROCESS_PATH = "/cgi-bin/bp_revision.cgi"

    def initialize(commerce, attributes)
      @commerce = commerce
      @attributes = attributes
    end

    # Get/Generate the transaction id number
    # Here I'm not sure of the exact algorithm used for the id generation.
    # All i know is that it's generated by the client, using the current system time and 
    # it's not necesarily unique so i think I will stay with a plain random number for now.
    # Any idea in this area is welcomed
    def transaction_id
      @transaction_id ||= (rand * 10000000000).to_i
    end

    def token
      @token ||= begin
        uri = URI.parse( @commerce.webpay_host + VALIDATION_PATH )

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
          post = Net::HTTP::Post.new uri.path
          post.set_form_data(to_hash)
          post["user-agent"] = "Webpay Gem"

          http.request post
        end

        if response.code == "200" && /ERROR=([a-zA-Z0-9]+)/.match(response.body)[1] == "0"
          /TOKEN=([a-zA-Z0-9]+)/.match(response.body)[1]
        end
      end
    end

    def mac
      @commerce.mac( param('&',false) )
    end

    def redirect_url
      @comemrce.redirect_url_for(token)
    end

    def process_url
      @commerce.webpay_host + PROCESS_PATH
    end

    def to_hash
      {
        'TBK_PARAM' => @commerce.encrypt(param),
        'TBK_VERSION_KCC' => '5.1',
        'TBK_CODIGO_COMERCIO' => @commerce.id.to_s,
        'TBK_CODIGO_COMERCIO_ENC' => @commerce.encrypt( @commerce.id.to_s )
      }
    end

    protected
      def param(splitter="#", include_mac=true)
        param = []

        param << "TBK_ORDEN_COMPRA=#{ @attributes[:order_id] }"
        param << "TBK_CODIGO_COMERCIO=#{ @commerce.id }"
        param << "TBK_ID_TRANSACCION=#{ transaction_id }"

        uri = URI.parse(@attributes[:notification_url])
        param << "TBK_URL_CGI_COMERCIO=#{ uri.path }"
        param << "TBK_SERVIDOR_COMERCIO=#{ /(\d{1,3}\.){3}\d{3}/.match(uri.host) ? uri.host : Webpay::Utils.local_ip }"
        param << "TBK_PUERTO_COMERCIO=#{ uri.port }"

        param << "TBK_VERSION_KCC=5.1"
        param << "PARAMVERIFCOM=1"

        param << "TBK_MAC=#{ mac }" if include_mac

        param << "TBK_ID_SESION=#{ @attributes[:session_id] }" if @attributes[:session_id]
        param << "TBK_MONTO=#{ (@attributes[:amount] * 100).to_i }"
        param << "TBK_TIPO_TRANSACCION=TR_NORMAL"
        param << "TBK_URL_EXITO=#{ @attributes[:return_url] }"
        param << "TBK_URL_FRACASO=#{ @attributes[:cancel_return_url] || @attributes[:return_url] }"

        param.join(splitter)
      end

  end
end

