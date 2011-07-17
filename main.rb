require 'sinatra'
require 'open-uri'
require 'nokogiri'
require 'openssl'
require 'builder'

# Root 
get '/' do
  erb :index
end

# Test that renders builder html within the webpage
post '/' do 
  # I couldn't get modules to load properly
  # Monkey patch to ensure that Builder will not auto escape xml text
  module Builder  
    class XmlBase  
      def _escape(text)  
        text  
      end  
    end  
  end   

  # Extracts the src attribute from an img tag
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

  # If this test passes then just grab a new value for @webpage from params[:scrape_url]
  @webpage = params[:scrape_url]

  # The ssl verification handles https connections
  document = Nokogiri::HTML(open(@webpage, :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))

  # Use Builder to construct a new html document based 
  # on the nokogiri 
  html = Builder::XmlMarkup.new(:indent => 2)

  # Creates a html document that displays x images per row
  @output = html.html{
    html.head{
      html.title "ImageScraper"
    }
    html.body{
      html.a( {:href => @webpage}, "Images scrapped from #{@webpage}")
      html.br
      
      PER_ROW = 5
      query = document.css('img')

      0.upto(query.size - 1) do |i|
        result = query[i]

        if(modify_src?(result))
          result = modify_src(result, webpage)
          html.img :src => result
        else
          html.text result
        end

        if(i % PER_ROW == 0 and i != 0)
          html.br
        end
      end
    }
  }

  erb :test
end
