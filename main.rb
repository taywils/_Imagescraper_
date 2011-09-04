require 'sinatra'
require 'open-uri'
require 'net/http'
require 'nokogiri'
require 'openssl'
require 'builder'

# Allow us to store session data locally via cookies 
enable :sessions

helpers do 
  # Monkey patch to ensure that Builder will not auto escape xml text
  module Builder  
    class XmlBase  
      def _escape(text)  
        text  
      end  
    end  
  end   
  
  # Checks if a url exists
  # @see http://snippets.dzone.com/posts/show/10225
  def ping?(url)
    url = URI.parse(url)
    Net::HTTP.start(url.host, url.port) do |http|
      return http.head(url.request_uri).code == "200"
    end
  end
  
  # Extracts the src attribute from an img tag
  # Just grabs all the text from between the src="gets_this_text" quotes
  def get_src(input)
    img_tag = input.to_s
    start_src = img_tag.index('src="') + 5
    src = ""

    while(img_tag[start_src] != '"')
      src += img_tag[start_src]
      start_src += 1
    end

    return src
  end

  # Determines if a src attribute needs to be modified
  # The // case handles when the images are stored on another server
  # The / or .. case handles when the images are stored on the parent directory
  # The [a-zA-Z0-9].* and doesn't contain http: or https: case handles when the image is stored
  # within the same level as the current page i.e http(s)://www.example.com/index.html/pic.jpg
  def modify_src?(input)
    src = get_src(input)

    if(src[0] == '/' and src[1] == '/')
      return true
    elsif(src[0] == '/' or (src[0] == '.' and src[1] == '.'))
      return true
    elsif(src.match('[a-zA-Z0-9].*') != nil and src.match('http:') == nil and src.match('https:') == nil)
      return true
    else
      return false
    end
  end

  # Modifies the src attribute by adding either the http or the tld
  # The // case handles when the images are stored on another server
  # The / or .. case handles when the images are stored on the parent directory
  # The [a-zA-Z0-9].* and doesn't contain http: or https: case handles when the image is stored
  # within the same level as the current page i.e http(s)://www.example.com/index.html/pic.jpg
  def modify_src(input, webpage)
    src = get_src(input)

    if(src[0] == '/' and src[1] == '/')
      return insert_http(src)
    elsif(src[0] == '/' or (src[0] == '.' and src[1] == '.'))
      return insert_tld(src, webpage)
    elsif(src.match('[a-zA-Z0-9].*') != nil and src.match('http:') == nil and src.match('https:') == nil)
      return insert_tld(src, webpage)
    end
  end

  # Appends http: to a src attribute
  def insert_http(src)
    http = "http:"
    return http += src
  end

  # Appends the top level domain to a src attribute
  # Handles the following cases
  # /something
  # ../somthing
  # something.extension
  def insert_tld(src, domain)
    if(src[0] == '/')  
      slash_count = 0
      end_i = 0
      
      # Copies the url upto the third '/' character
      # Example http://www.example.com/images
      # will result in http://www.example.com
      0.upto(domain.length) do |i|
        if(slash_count == 3)
          end_i = i - 1
          break
        end

        if(domain[i] == '/')
          slash_count += 1
        end
      end

      new_domain = domain[0, end_i]
      return new_domain += src
    elsif(src[0] == '.' and src[1] == '.')
      # Removes the parent directory reference
      # Example ../some_directory/somefile.xyz
      # will result in /some_directory/somefile.xyz
      src = src[2, src.length]
      slash_count = 0
      end_i = 0

      0.upto(domain.length) do |i|
        if(slash_count == 3)
          end_i = i
          break
        end

        if(domain[i] == '/')
          slash_count += 1
        end
      end

      new_domain = domain[0, end_i]
      return new_domain += src
    elsif(src.match('[a-zA-Z0-9].*') != nil and src.match('http:') == nil and src.match('https:') == nil)
      trimmed_domain = ""

      domain.length.downto(0) do |i|
        if(domain[i] == '/')
          trimmed_domain = domain[0, i + 1]
          break
        end
      end

      return trimmed_domain += src
    end
  end  
  
  def download_images(webpages)
    # Create the folder to hold the images and give it a unique timestamp
    current_time = Time.now.to_s.gsub(/:/, '_').gsub(/-/, '_')
    Dir.mkdir(current_time)
    Dir.chdir("./#{current_time.to_s}")

    # For each webpage, extract the img sources and save their contents to the HD
    webpages.each do |webpage|
      document = Nokogiri::HTML(open(webpage, :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))
      query = document.css('img')
      
      0.upto(query.size - 1) do |i|
        img_src_tag = query[i]
        img_src = get_src(img_src_tag) if get_src(img_src_tag) != nil
	# Hack to check if the image url is a valid http or http(s) protocol
	# This assumes that the url will not be https:
	if(img_src.to_s[0] != 'h')
		valid_src = insert_http(img_src.to_s)
	else
		valid_src = img_src.to_s
	end
        file_name = Time.now.nsec.to_s + '.png'
        open(file_name, 'wb') do |file|
          file << open(valid_src).read 
        end
      end
    end
    
    # Return to the directory where this script is stored
    Dir.chdir("..")   
  end

  def generate_page(webpage, document)
    # Use Builder to construct a new html document based 
    # on the nokogiri 
    html = Builder::XmlMarkup.new(:indent => 2)

    # Creates a html document that displays the desired number of images_per_row
    output = html.html{
       html.head{
        html.title "ImageScraper"
      }
      html.body{
        html.a( {:href => webpage}, "Images scrapped from #{webpage}")
        html.br
        
        images_per_row = 5
        query = document.css('img')

        0.upto(query.size - 1) do |i|
          result = query[i]

          if(modify_src?(result))
            result = modify_src(result, webpage)
            html.img :src => result
          else
            html.text result
          end

          if(i % images_per_row == 0 and i != 0)
            html.br
          end
        end
      }
    }
    return output
  end
end

# Homepage 
get '/' do
  session['pages'] ||= []    
  erb :index
end

post '/' do 
  @webpage = params[:scrape_url]
  session['pages'].insert(0, @webpage)
  erb :index
end

# Download page
# This feature is incomplete
get '/download' do
  session['pages'] ||= []
  erb :downloading  
end

# Upload text file that will hold urls
# This feature is incomplete 
get '/upload' do
  session['content'] ||= ""
  erb :upload 
end

post '/upload' do
  session['content'] = params[:upload_file][:tempfile].readlines
  erb :upload
end
