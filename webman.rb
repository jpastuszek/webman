require 'uri'
require 'em-http-request/lib/em-http-request'
require 'hpricot'

class Referer
  include URI
  attr_reader :uri

  def initialize(uri)
    @uri = URI.parse(uri)
    not @uri.relative? or raise ArgumentError, 'Referer needs to be absolute URI'
  end
end

class Loader
  $queue = []
  $queue_timer = nil

  def initialize(uri, referer = nil, agent = 'Mozilla/5.0 (Macintosh; U; PPC Mac OS X Mach-O; en-US; rv:1.8.1.1) Gecko/20061204 Firefox/2.0.0.1', redirects = 8, connect_timeout = 5, inactivity_timeout = 5, max_connections = 10, &block)

    do_load = lambda {
      headers = {}
      headers['User-Agent'] = agent
      headers['Referer'] = referer.uri.to_s if referer

      puts "Loading: #{uri.to_s}" + if referer
        " [#{referer.uri.to_s}]"
      else
        ""
      end
      # requires v1.0
      #http = EventMachine::HttpRequest.new(uri.to_s, :connect_timeout => connect_timeout, :inactivity_timeout => inactivity_timeout).get(:head => headers, :redirects => redirects)
       
      http = EventMachine::HttpRequest.new(uri.to_s).get(:head => headers, :redirects => redirects)
      http.callback {
        puts "Loaded #{http.uri.to_s}"
        block.call(http.response_header.status, http.response_header['CONTENT_TYPE'], http.response, http.uri.to_s)
      }
    }

    if EM.connection_count > max_connections
      $queue << do_load
      $queue_timer = EventMachine::PeriodicTimer.new(1) do
        puts "[#{uri.to_s}]: Max connections reached, wainting: on queue: #{$queue.length}"
        until EM.connection_count > max_connections
          if $queue.empty?
            $queue_timer.cancel 
            $queue_timer = nil
          else
            $queue.pop.call 
          end
        end
      end unless $queue_timer
    else
      do_load.call
    end
  end
end

class Webman
  Image = Struct.new(:data, :type, :final_uri)
  class Page
    attr_reader :url
    attr_reader :html
    attr_reader :final_uri

    def initialize(uri, data, final_uri)
      @uri = uri
      @html = Hpricot(data)
      @final_uri = final_uri
    end

    def load(uri, &block)
      Webman.new(uri, @final_uri, &block)
    end
  end

  def initialize(uri, referer, &block)
    uri = URI.parse(uri.to_s)
    referer = Referer.new(referer.to_s) if referer

    if uri.relative? and not referer
      raise ArgumentError, "URI (#{uri.to_s}) is relative but no referer given"
    end

    uri = uri.to_s
    uri = case uri
      when /^http/
        uri
      when /^\// # http://gafds.com/ + uri
        referer.uri.to_s.gsub(/(.*[^:]:\/\/[^\/]*).*/, '\1') + uri
      when /^[^\/]/ # http://gafds.com/last/sub/dir/ + uri
        referer.uri.to_s.gsub(/(.*\/).*/, '\1') + uri
    end

    Loader.new(uri, referer) do |status, mime, data, final_uri|
      if status == 200
        puts mime
        case mime.split(';')[0]
          when 'text/html'
            block.call Page.new(uri, data, final_uri)
          when /image\/(.*)/
            block.call Image.new(data, $+, final_uri)
          else
            fail "Unknown mime type: #{mime}"
        end
      else
        puts "Got non 200 status response: #{status}"
        # block not called - not much we can do here
      end
    end
  end

  def self.load(uri, &block)
    new(uri, nil, &block)
  end
end

