require 'rubygems'
require 'sinatra'

get /hello/ do
  'hello'
end

get /query/ do
  request.query_string
end

get /redirect/ do
  redirect to('/hello')
end

get /page/ do
  "<test>test</test>"
end

get /image.png/ do
  send_file 'test.png'
end

get /link,full/ do
  '<a href="http://localhost:1212/hello">hello</a>'
end

get /link,short/ do
  '<a href="hello">hello</a>'
end

get /link,root/ do
  '<a href="hello">/hello</a>'
end

get /pid/ do
  Process.pid.to_s
end

