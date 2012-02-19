require 'md5'

module SmugRaw

  UPLOAD_ENDPOINT='http://upload.smugmug.com/'.freeze
  UPLOAD_ENDPOINT_SECURE='https://upload.smugmug.com/'.freeze

  END_POINT='http://api.smugmug.com/services/'.freeze
  END_POINT_SECURE='https://secure.smugmug.com/services/'.freeze

  SMUGMUG_OAUTH_REQUEST_TOKEN=(END_POINT + 'oauth/getRequestToken.mg').freeze
  SMUGMUG_OAUTH_AUTHORIZE=(END_POINT + 'oauth/authorize.mg').freeze
  SMUGMUG_OAUTH_ACCESS_TOKEN=(END_POINT + 'oauth/getAccessToken.mg').freeze

  SMUGMUG_OAUTH_REQUEST_TOKEN_SECURE=(END_POINT_SECURE + 'oauth/getRequestToken.mg').freeze
  SMUGMUG_OAUTH_AUTHORIZE_SECURE=(END_POINT_SECURE + 'oauth/authorize.mg').freeze
  SMUGMUG_OAUTH_ACCESS_TOKEN_SECURE=(END_POINT_SECURE + 'oauth/getAccessToken.mg').freeze

  # NOTE: smugmug.reflection.getMethods is broken; it doesn't return all methods
  #VER = '1.3.0'
  VER = '1.2.2'

  REST_PATH=(END_POINT + 'api/json/' + VER + '/').freeze
  UPLOAD_PATH=UPLOAD_ENDPOINT
  REPLACE_PATH=(END_POINT + '/replace/' + VER + '/').freeze

  REST_PATH_SECURE=(END_POINT_SECURE + '/json/' + VER + '/').freeze
  UPLOAD_PATH_SECURE=UPLOAD_ENDPOINT_SECURE
  REPLACE_PATH_SECURE=(END_POINT_SECURE + '/replace/' + VER + '/').freeze

  PHOTO_SOURCE_URL='http://farm%s.static.flickr.com/%s/%s_%s%s.%s'.freeze
  URL_PROFILE='http://www.flickr.com/people/'.freeze
  URL_PHOTOSTREAM='http://www.flickr.com/photos/'.freeze
  #URL_SHORT='http://flic.kr/p/'.freeze
  URL_SHORT='http://smu.gs'.freeze # FIXME: this definitely won't work

  # Root class of the smugmug api hierarchy.
  class SmugMug < Request
    # Authenticated access token
    attr_accessor :access_token

    # Authenticated access token secret
    attr_accessor :access_secret

    def self.build(methods); methods.each { |m| build_request m } end

    def initialize # :nodoc:
      raise "No API key or secret defined !" if SmugRaw.api_key.nil? or SmugRaw.shared_secret.nil?
      @oauth_consumer = OAuthClient.new(SmugRaw.api_key, SmugRaw.shared_secret)
      @oauth_consumer.proxy = SmugRaw.proxy
      @oauth_consumer.user_agent = USER_AGENT
      @access_token = @access_secret = nil
      method_response = call('smugmug.reflection.getMethods')
      # NOTE: SmugMug doesn't export reflection.* in their list of methods
      method_response['Methods'].push 'smugmug.reflection.getMethods'
      SmugMug.build(method_response['Methods']) if SmugMug.smugmug_objects.empty?
      super self
    end

    # This is the central method. It does the actual request to the smugmug server.
    #
    # Raises FailedResponse if the response status is _failed_.
    def call(req, args={}, &block)
      rest_path = SmugRaw.secure ? REST_PATH_SECURE :  REST_PATH
      http_response = @oauth_consumer.post_form(rest_path, @access_secret, {:oauth_token => @access_token}, build_args(args, req))
      process_response(req, http_response.body)
    end

    # Get an oauth request token.
    #
    #    token = smugmug.get_request_token(:oauth_callback => "http://example.com")
    def get_request_token(args = {})
      smugmug_oauth_request_token = SmugRaw.secure ? SMUGMUG_OAUTH_REQUEST_TOKEN_SECURE : SMUGMUG_OAUTH_REQUEST_TOKEN
      @oauth_consumer.request_token(smugmug_oauth_request_token, args)
    end

    # Get the oauth authorize url.
    #
    #  auth_url = smugmug.get_authorize_url(token['oauth_token'], :perms => 'Access=Full&Permissions=Modify')
    #  auth_url = smugmug.get_authorize_url(token['oauth_token'], :perms => {:Access=>'Full', :Permissions=>'Modify'})
    def get_authorize_url(token, args = {})
      smugmug_oauth_authorize = SmugRaw.secure ? SMUGMUG_OAUTH_AUTHORIZE_SECURE : SMUGMUG_OAUTH_AUTHORIZE
      @oauth_consumer.authorize_url(smugmug_oauth_authorize, args.merge(:oauth_token => token))
    end

    # Get an oauth access token.
    #
    #  smugmug.get_access_token(token['oauth_token'], token['oauth_token_secret'], oauth_verifier)
    def get_access_token(token, secret)#, verify)
      smugmug_oauth_access_token = SmugRaw.secure ? SMUGMUG_OAUTH_ACCESS_TOKEN_SECURE : SMUGMUG_OAUTH_ACCESS_TOKEN
      access_token = @oauth_consumer.access_token(smugmug_oauth_access_token, secret, :oauth_token => token)#, :oauth_verifier => verify)
      @access_token, @access_secret = access_token['oauth_token'], access_token['oauth_token_secret']
      access_token
    end

    # Use this to upload the photo in _file_.
    #
    #  smugmug.upload_photo '/path/to/the/photo', :title => 'Title', :description => 'This is the description'
    #
    # See http://www.smugmug.com/services/api/upload.api.html for more information on the arguments.
    def upload_image(file, args={})
      upload_path = SmugRaw.secure ? UPLOAD_PATH_SECURE : UPLOAD_PATH
      upload_smugmug(upload_path, file, args)
    end

    # Use this to replace the photo with :photo_id with the photo in _file_.
    #
    #  smugmug.replace_photo '/path/to/the/photo', :photo_id => id
    #
    # See http://www.smugmug.com/services/api/replace.api.html for more information on the arguments.
#    def replace_photo(file, args={})
#      replace_path = SmugRaw.secure ? REPLACE_PATH_SECURE : REPLACE_PATH
#      upload_smugmug(replace_path, file, args)
#    end

    private
    def build_args(args={}, method = nil)
      full_args = {'format' => 'json', 'nojsoncallback' => '1'}
      full_args['method'] = method if method
      args.each {|k, v|
        v = v.to_s.encode("utf-8").force_encoding("ascii-8bit") if RUBY_VERSION >= "1.9"
        full_args[k.to_s] = v
      }
      full_args
    end

    def process_response(req, response)
      if response =~ /^<\?xml / # upload_photo returns xml data whatever we ask
        if response[/stat="(\w+)"/, 1] == 'fail'
          msg = response[/msg="([^"]+)"/, 1]
          code = response[/code="([^"]+)"/, 1]
          raise FailedResponse.new(msg, code, req)
        end
        type = response[/<(\w+)/, 1]
        h = {
          "secret" => response[/secret="([^"]+)"/, 1],
          "originalsecret" => response[/originalsecret="([^"]+)"/, 1],
          "_content" => response[/>([^<]+)<\//, 1]
        }.delete_if {|k,v| v.nil? }
        Response.build h, type
      else
        json = JSON.load(response.empty? ? "{}" : response)
        raise FailedResponse.new(json['message'], json['code'], req) if json.delete('stat') == 'fail'
        # NOTE: SmugMug likes to add the method name to the response but it just gets in the way
        json.delete('method')
        # NOTE: Response.build strips off the surrounding { type_name => <value> }
        #       Flickr responses always come in the form { photos => { photo => [ {photo1}, ... ] } }
        #       SmugMug responses always look like: { photos => [ {photo1}, ... ] }
        #       So we send Response.build an either 'key', Array or 'key', Hash
        # type, json = json.to_a.first if json.size == 1 and json.all? {|k,v| v.is_a? Hash }
        type, json = json.to_a.first if json.size == 1 and json.all? {|k,v| (v.is_a?(Hash) || v.is_a?(Array)) }
        Response.build json, type
      end
    end

    def upload_smugmug(method, file, args={})
      args['photo'] = File.open(file, 'rb')
      args['MD5Sum'] = MD5.file(file).to_s
      args['ByteCount'] = args['photo'].lstat.size.to_s #File.open(file).lstat.size.to_s
      args['ResponseType'] = 'JSON'
      args['Version'] = VER
      args = build_args(args)
      http_response = @oauth_consumer.post_multipart(method, @access_secret, {:oauth_token => @access_token}, args)
      process_response(method, http_response.body)
    end
  end

  class << self
    # Your smugmug API key, see http://www.smugmug.com/services/api/keys for more information
    attr_accessor :api_key

    # The shared secret of _api_key_, see http://www.smugmug.com/services/api/keys for more information
    attr_accessor :shared_secret

    # Use a proxy
    attr_accessor :proxy

    # Use ssl connection
    attr_accessor :secure

    BASE58_ALPHABET="123456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ".freeze
    def base58(id)
      id = id.to_i
      alphabet = BASE58_ALPHABET.split(//)
      base = alphabet.length
      begin
        id, m = id.divmod(base)
        r = alphabet[m] + (r || '')
      end while id > 0
      r
    end

#    def url(r);   PHOTO_SOURCE_URL % [r.farm, r.server, r.id, r.secret, "",   "jpg"]   end
#    def url_m(r); PHOTO_SOURCE_URL % [r.farm, r.server, r.id, r.secret, "_m", "jpg"] end
#    def url_s(r); PHOTO_SOURCE_URL % [r.farm, r.server, r.id, r.secret, "_s", "jpg"] end
#    def url_t(r); PHOTO_SOURCE_URL % [r.farm, r.server, r.id, r.secret, "_t", "jpg"] end
#    def url_b(r); PHOTO_SOURCE_URL % [r.farm, r.server, r.id, r.secret, "_b", "jpg"] end
#    def url_z(r); PHOTO_SOURCE_URL % [r.farm, r.server, r.id, r.secret, "_z", "jpg"] end
#    def url_o(r); PHOTO_SOURCE_URL % [r.farm, r.server, r.id, r.originalsecret, "_o", r.originalformat] end
#    def url_profile(r); URL_PROFILE + (r.owner.respond_to?(:nsid) ? r.owner.nsid : r.owner) + "/" end
#    def url_photopage(r); url_photostream(r) + r.id end
#    def url_photosets(r); url_photostream(r) + "sets/" end
#    def url_photoset(r); url_photosets(r) + r.id end
#    def url_short(r); URL_SHORT + base58(r.id) end
#    def url_short_m(r); URL_SHORT + "img/" + base58(r.id) + "_m.jpg" end
#    def url_short_s(r); URL_SHORT + "img/" + base58(r.id) + ".jpg" end
#    def url_short_t(r); URL_SHORT + "img/" + base58(r.id) + "_t.jpg" end
#    def url_photostream(r)
#      URL_PHOTOSTREAM +
#        if r.respond_to?(:pathalias) and r.pathalias
#          r.pathalias
#        elsif r.owner.respond_to?(:nsid)
#          r.owner.nsid
#        else
#          r.owner
#        end + "/"
#    end

  end
end

