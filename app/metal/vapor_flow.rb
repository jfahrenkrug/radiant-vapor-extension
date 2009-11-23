require 'cgi'

class VaporFlow
  include Vaporizer
  
  # Radiant must be restarted if the configuration changes for this setting
  @@use_regexp = nil
  class << self  
    def call(env)
      if env["PATH_INFO"].blank?
        return send_to_radiant
      end
      full_url = 'http://' + env["HTTP_HOST"] +  env["PATH_INFO"]
      relative_url = env["PATH_INFO"].sub(/^\//,'') #clean off the first slash, like it is stored in the db
      db_escaped_key = ActiveRecord::Base.connection.adapter_name =~ /mysql/i ? '`key`' : 'key'
      sql = "SELECT * FROM config where #{db_escaped_key} = 'vapor.use_regexp'"
      if @@use_regexp.nil?
        config_key = Radiant::Config.connection.select_one(sql)
        @@use_regexp = (config_key && config_key['value'] == 'true') ? true : false
      end
      if @@use_regexp
        catch_with_regexp(full_url, relative_url)
      else
        catch_without_regexp(full_url, relative_url)
      end
    end
    
    def catch_with_regexp(full_url, relative_url)
      FlowMeter.all.sort.reverse.each do |meter|
        key = meter[0]
        value = meter[1]
        match = full_url.match(Regexp.new('^'+key))
        match = relative_url.match(Regexp.new('^'+key)) unless match
        if (match)
          status = value[1].to_i
          redirect_url = self.match_substitute(value[0], match)
          return [status, {"Location" => CGI.unescape(local_or_external_path(redirect_url))}, [status.to_s]]
          break
        else
          result = self.send_to_radiant
        end
      end
      return result
    end

    def catch_without_regexp(full_url, relative_url)
      full_url = full_url.sub(/\/$/, '') unless full_url == '/' # drop the trailing slash for lookup
      relative_url = relative_url.sub(/\/$/, '') unless relative_url == '/' # drop the trailing slash for lookup
      a_match = FlowMeter.all[full_url]
      a_match = FlowMeter.all[relative_url] unless a_match
      unless a_match.nil?
        status = a_match[1].to_i
        redirect_url = a_match[0]
        [status, {"Location" => CGI.unescape(local_or_external_path(redirect_url))}, [status.to_s]]
      else
        self.send_to_radiant
      end
    end
    
    def send_to_radiant
      [404, {'Content-Type' => 'text/html'}, ['Off to Radiant we go!']]
    end
  end
end