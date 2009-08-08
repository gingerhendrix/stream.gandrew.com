require 'rubygems'
require 'sinatra/base'
require 'net/http'
require 'haml'
require 'json'
require 'couchrest'

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

    get '/commits' do
      res = Net::HTTP.get_response(URI.parse("http://localhost:5984/github_commits/_view/github/all_commits_by_date?count=20&descending=true"))
      @commits = JSON.parse(res.body)
      @commits = squash_commits(@commits['rows'])
      haml :commits
    end
  
    def squash_commits(array)
     squash array do |ref_commit, commit|
       ref_commit['value']['repository'] == commit['value']['repository'] &&
       ref_commit['value']['authored_date'].slice(0,10) == commit['value']['authored_date'].slice(0,10)            
     end  
    end
    
    def squash(array)
      ref_item = nil
      squashed = []
      array.each do |item|
        if ref_item && yield(ref_item, item)
          prev_item = squashed.pop()
          if(prev_item.kind_of? Array)
            prev_item.push(item)
            squashed.push(prev_item)
          else
            squashed_item = []
            squashed_item.push(prev_item)
            squashed_item.push(item)
            squashed.push(squashed_item)
          end
        else
          ref_item = item
          squashed.push(item)
        end
      end
      squashed
    end
  end
end

