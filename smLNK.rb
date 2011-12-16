#
#
#                 #       #     # #    # .rb v1.0
#   ####   #    # #       ##    # #   #
#  #       ##  ## #       # #   # #  #
#   ####   # ## # #       #  #  # ###
#       #  #    # #       #   # # #  #
#  #    #  #    # #       #    ## #   #
#   ####   #    # ####### #     # #    #
#
#  smLNK.rb by Jonathon Marshall
#  based of the original smLNK by Jonathon Marshall and William Rockwood (2001)
#  useless comments by Tim Burden
#

require 'rubygems'
require 'bundler/setup'

require 'sinatra'
require 'digest/sha1'
require 'haml'
require 'redis'
require 'json'
require 'rqrcode'

if ! ENV['VCAP_SERVICES'].nil?
  vcap = JSON.parse(ENV['VCAP_SERVICES'])
  redis_host = vcap["redis-2.2"][0]["credentials"]["hostname"]
  redis_port = vcap["redis-2.2"][0]["credentials"]["port"]
  redis_pass = vcap["redis-2.2"][0]["credentials"]["password"]
  redis_name = vcap["redis-2.2"][0]["credentials"]["name"]
else
  redis_host = "localhost"
  redis_port = "6379"
  redis_pass = nil
  redis_name = "smlnk"
end

$redis = Redis.new(:host => redis_host, :port => redis_port, :db => redis_name, :password => redis_pass)

set :haml, :format => :html5
set :public, File.dirname(__FILE__) + '/static'

get '/' do
  haml :index, :locals => { :host => $host }
end

post '/' do
  longurl = params[:longurl]
  shorturl = "http://#{request.host}"

  if request.port != 80
    shorturl = shorturl << ":#{request.port}"
  end

  if longurl.nil? or ! longurl.match('^http:\/\/')
    haml :error, :locals => { :msg => 'Invalid URL' }, :layout => (request.xhr? ? false : :layout)
  elsif longurl.length < (shorturl.length + 2)
    haml :error, :locals => { :msg => 'URL Too Short' }, :layout => (request.xhr? ? false : :layout)
  else
    sha1 = Digest::SHA1.hexdigest longurl
    id = $redis.get "sha1:#{sha1}:id" || nil
    if id.nil?
      counter = $redis.incr "next:link:id"
      id = counter.to_s(36)
      $redis.setnx "sha1:#{sha1}:id", id
      $redis.setnx "link:#{id}:id", longurl
    end

    smlnk = "#{shorturl}/#{id}"
    qr = RQRCode::QRCode.new(smlnk)

    haml :new, :locals => { :link => smlnk, :qr => qr }, :layout => (request.xhr? ? false : :layout)
  end
end

get %r{^/([\w][^/-]*)$} do |x|
  id = "#{x}".to_i(36).to_s
  link = $redis.get "link:#{id}:id" || nil
  haml :error, :locals => { :msg => 'Invalid Key' }, :layout => (request.xhr? ? false : :layout) if link.nil?
  redirect link, 302
end

