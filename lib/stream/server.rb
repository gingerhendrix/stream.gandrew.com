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
    
    get '/date/:year/:month' do |year, month|
      @year = year.to_i
      @month = month.to_i
      @date = DateTime.civil(@year, @month)
      @user = get_or_wait('http://localhost:4567/github/user_info.js?username=gingerhendrix')
      return if @user.nil?
      @commits = get_or_wait("http://localhost:4567/github/all_commits_by_month.js?username=gingerhendrix&year=#{year}&month=#{month}")
      return if @commits.nil?
      @commits = squash_commits(@commits['data']['rows'].map {|c| c['value'] })
      haml :month
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
      data = get_or_wait("http://localhost:4567/github/commit_counts_by_month.js?username=gingerhendrix&project=#{name}")
      return if data.nil?
      data = data['data']
      
      startYear = 2007
      startMonth = 1
      endMonth = 9
      endYear = 2009
      
      currentYear = startYear
      currentMonth = startMonth
      values = []
      data['rows'].each do |row|
         year= row['key'][2][0..3].to_i
         month = row['key'][5..6].to_i
         pad values, dateDiff(year, month, currentYear, currentMonth)
         values.push(row['value'])
         currentYear = year
         currentMonth = month
      end
      pad values, dateDiff(endYear, endMonth, currentYear, currentMonth)
      
      redirect "http://sparklines.bitworking.info/spark.cgi?type=impulse&d=#{values.join(',')}&height=20&limits=0,30&upper=10&above-color=red&below-color=gray&width=4"
    end
    
    def dateDiff(sy, sm, cy, cm)
      ((sy-cy) * 12) + (sm - cm)
    end
    
    def pad(arr, n)
      arr.fill(0, arr.length, n)
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
        result = "Error!"
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

