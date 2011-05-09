require 'webman'
require 'open-uri'
require 'em-spec/lib/em-spec/rspec'

def url(*args)
  "http://localhost:1212/#{args.join('/')}"
end

def server_pid
  open(url 'pid').read.to_i
end

def start_server
  server = IO.popen('ruby webman_test_server.rb -p 1212 > webman_test_server.log')
  loop do
    out = open(url 'hello').read rescue Errno::ECONNREFUSED
    break if out == "hello"
    sleep 0.2
  end
  #puts "got server: #{server_pid}"
end

def stop_server
  pid = server_pid
  #puts "stopping server: #{server_pid}"
  Process.kill(15, server_pid)
end

describe Referer do
  it 'should only accept absolute URIs' do
    lambda {
      Referer.new('http://basldsf')
    }.should_not raise_exception

    lambda {
      Referer.new('basldsf')
    }.should raise_exception ArgumentError
  end

  it 'should provide parsed URI object' do
      ref = Referer.new('http://basldsf')
      ref.uri.host.should == 'basldsf'

      ref.uri.should be_kind_of URI::HTTP
  end
end

describe Loader do
  include EM::SpecHelper

  before :all do
    start_server
  end

  it 'should follow redirects' do
    em do
      Loader.new(url 'hello') do |status, mime, data|
        status.should == 200
        data.should == 'hello'
        done
      end
    end
  end

  it 'should respect query options' do
    em do
      Loader.new(url 'query?client=safari&rls=en&q=xbrna&ie=UTF-8&oe=UTF-8') do |status, mime, data|
        status.should == 200
        data.should == 'client=safari&rls=en&q=xbrna&ie=UTF-8&oe=UTF-8'
        done
      end
    end
  end

  it 'should follow redirects and provide final uri' do
    em do
      Loader.new(url 'redirect') do |status, mime, data, uri|
        status.should == 200
        uri.should == url('hello')
        data.should == 'hello'
        done
      end
    end
  end

  it 'should load web page' do
    em do
      Loader.new(url 'page') do |status, mime, data|
        status.should == 200
        data.should == "<test>test</test>"
        done
      end
    end
  end

  after :all do
    stop_server
  end
end

describe Webman do
  include EM::SpecHelper

  before :all do
    start_server
  end

  it 'should load a web page' do
    em do
      Webman.load(url 'page') do |page|
        page.should be_kind_of Webman::Page
        page.html.search('test').inner_html.should == 'test'
        done
      end
    end
  end

  it 'should load a web page with query' do
    em do
      Webman.load(url 'query?client=safari&rls=en&q=xbrna&ie=UTF-8&oe=UTF-8') do |page|
        page.html.inner_html.should == 'client=safari&rls=en&q=xbrna&ie=UTF-8&oe=UTF-8'
        done
      end
    end
  end

  it 'should load an image' do
    em do
      Webman.load(url 'image.png') do |image|
        image.should be_kind_of Webman::Image
        image.data.length.should > 200
        image.type.should == 'png'
        done
      end
    end
  end

  it 'should allow chaining' do
    em do
      Webman.load(url 'link,full') do |page|
        page.should be_kind_of Webman::Page
        page.load(page.html.search('a')[0].attributes['href']) do |page2|
          page2.should be_kind_of Webman::Page
          page2.html.inner_html.should == 'hello'
          done
        end
      end
    end
  end

  it 'should load subURI' do
    em do
      Webman.load(url 'link,short') do |page|
        page.should be_kind_of Webman::Page
        page.load(page.html.search('a')[0].attributes['href']) do |page2|
          page2.should be_kind_of Webman::Page
          page2.html.inner_html.should == 'hello'
          done
        end
      end
    end
  end

  it 'should load subURI starting with /' do
    em do
      Webman.load(url 'link,root') do |page|
        page.should be_kind_of Webman::Page
        page.load(page.html.search('a')[0].attributes['href']) do |page2|
          page2.should be_kind_of Webman::Page
          page2.html.inner_html.should == 'hello'
          done
        end
      end
    end
  end

  after :all do
    stop_server
  end
end

