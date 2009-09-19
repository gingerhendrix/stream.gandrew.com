require 'rubygems'
require 'sinatra/base'
require 'net/http'
require 'haml'
require 'activesupport'
require 'couchrest'

module Stream
  class Server < Sinatra::Base
    puts File.dirname(__FILE__) + '/../../public'
    enable :static
    set :public, File.dirname(__FILE__) + '/../../public'

    get '/' do
      @user = get_or_wait('http://localhost:4567/github/user_info.js?username=gingerhendrix')
      return if @user.nil?
      @commits = get_or_wait("http://localhost:4567/github/all_commits.js?username=gingerhendrix")
      return if @commits.nil?
      @commits = squash_commits(@commits['data']['rows'].map {|c| c['value'] })
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
    
    get '/sparkline/:name' do |name|
      view = "http://localhost:5984/github_commits/_design/github/_view/commits_by_month?group=true&group_level=3&startkey=%5B%22gingerhendrix%22,%22#{name}%22%5D&endkey=%5B%22gingerhendrix%22,%22#{name}%22,%7B%7D%5D"
      res = Net::HTTP.get_response(URI.parse(view));
      data = JSON.parse(res.body)
      startYear = 2007
      startMonth = 1
      endMonth = 8
      endYear = 2009
      values = []
      while(startYear <= endYear || startMonth <= endMonth )
        if(data['rows'][0] && data['rows'][0]['key'] && data['rows'][0]['key'][2] == "#{startYear}-#{startMonth.to_s.rjust(2, '0')}")
          commits = data['rows'].shift
          values.push(commits['value'])
        else
          values.push(0)
        end
        startMonth+=1;
        if(startMonth > 12)
          startYear += 1;
          startMonth = 1;
        end
      end
      redirect "http://sparklines.bitworking.info/spark.cgi?type=impulse&d=#{values.join(',')}&height=20&limits=0,30&upper=10&above-color=red&below-color=gray&width=4"
    end
    
    get '/repo/:name' do |name|
      @user = get_or_wait('http://localhost:4567/github/user_info.js?username=gingerhendrix');
      return if @user.nil?
      @repo = get_or_wait("http://localhost:4567/github/commits.js?username=gingerhendrix&repo=#{name}")
      return if @repo.nil?
      @commits = squash_commits(@repo['data'])      
      haml :repo 
    end

    get '/commits' do
      @commits = get_or_wait("http://localhost:4567/github/all_commits.js?username=gingerhendrix")
      @commits = squash_commits(@commits['data']['rows'])
      haml :commits
    end
    
    get '/gists' do
      @gists = get_or_wait("http://localhost:4567/gist/gists.js?username=gingerhendrix")
      haml :gists
    end

    def get_or_wait(url)
      res = Net::HTTP.get_response(URI.parse(url));
      result = nil
      if res.code== '200'
        result = ActiveSupport::JSON.decode(res.body)
        result
      elsif  res.code=='202'
        redirect "http://#{@request.host}:#{@request.port}/wait#{@request.fullpath}"
      else
        "Error!"
      end
      result
    end
  
    def squash_commits(array)
     squash array do |ref_commit, commit|
       ref_commit['repository'] == commit['repository'] &&
       Time.parse(ref_commit['authored_date']).yday == Time.parse(commit['authored_date']).yday
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

