require 'rubygems'
require 'sinatra/base'
require 'net/http'
require 'haml'
require 'json'

module Stream
  class Server < Sinatra::Base

    get '/' do
      res = Net::HTTP.get_response(URI.parse('http://localhost:4567/github/user_info.js?username=gingerhendrix'));
      @user = JSON.parse(res.body)
      haml :index
    end
    
    get '/wait/*' do
      original_url = "http://#{@request.host}:#{@request.port}/#{@params[:splat]}"
      res = Net::HTTP.get_response(URI.parse(original_url));
      if res.code== '303'      
        @response.status = "202"
        @response['refresh'] = "5"
        haml :wait
      else
        @response.status = "200"
        @response['refresh'] = "1;#{original_url}"
        haml :wait
      end
    end
    
    get '/repo/:name' do |name|
      res = Net::HTTP.get_response(URI.parse("http://localhost:4567/github/commits.js?username=gingerhendrix&repo=#{name}"));
      if res.code== '200'
        @repo = JSON.parse(res.body)
        haml :repo
      elsif  res.code=='202'
        redirect "http://#{@request.host}:#{@request.port}/wait#{@request.fullpath}"
      else
        "Error!"
      end
    end
    
  end
end

