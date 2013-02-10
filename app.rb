require 'sinatra'
require 'json'
require 'net/https'
require 'openssl'
require 'nokogiri'
require 'open-uri'
require 'pp'

set server: 'thin'

class Scrape
  def self.images(uri_string)
    raw_img_tags = Nokogiri::HTML(open(uri_string, :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE)).css('img')
    img_array = []
    0.upto(raw_img_tags.size - 1) do |index|
      img_array.push index, raw_img_tags[index].to_s
    end
    img_hash = Hash[*img_array]
  end
end

get '/' do
  erb :main, :layout => :layout
end

post '/validate' do
  url = params["url"]
  begin
    uri = URI(url.to_s)
    code = Net::HTTP.get_response(uri).code
    if code == "200"
      Scrape.images(uri.to_s).to_json()
    else
      {:error => "error", :code => code}.to_json()
    end
  rescue Exception => exception
    puts "#{exception.class}: #{exception.message}"
    {:error => "error", :code => "invalid"}.to_json()
  end
end
