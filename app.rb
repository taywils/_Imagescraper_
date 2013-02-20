require 'sinatra'
require 'json'
require 'openssl'
require 'nokogiri'
require 'open-uri'
require 'pp'

set server: 'thin'

class Scrape
  def self.images(uri_string)
    uri_string = self.fix_url(uri_string)
    raise Exception if uri_string == :fix_url_failed
    raw_img_tags = Nokogiri::HTML(open(uri_string, :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE)).css('img')
    img_array = []
    0.upto(raw_img_tags.size - 1) do |index|
      img_array.push index, raw_img_tags[index].to_s
    end
    img_hash = Hash[*img_array]
  end

private

  # Utility method for fix_url
  def self.ping?(url)
    uri = URI(url)
    begin
      Nokogiri::HTML(open(uri.to_s, :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE)).css('title')
      true
    rescue Exception => exception
      false
    end
  end

  # Utility method for fix_url
  def self.try_url(url, option)
    case option
      when 1
        return "http://" + url
      when 2
        return "http://www." + url
      when 3
        return "https://" + url
      when 4
        return "https://www." + url
      else
        return url
    end
  end

  # Tries different urls given an initial guess
  def self.fix_url(url)
    0.upto(4) do |n|
      if self.ping?(self.try_url(url, n))
        return self.try_url(url, n)
      end
    end
    :fix_url_failed
  end
end

get '/' do
  erb :main, :layout => :layout
end

post '/validate' do
  url = params["url"]
  begin
    uri = URI(url.to_s)
    Scrape.images(uri.to_s).to_json()
  rescue Exception => exception
    puts "#{exception.class}: #{exception.message}"
    {:error => "error", :code => "invalid"}.to_json()
  end
end
