#!/usr/bin/env ruby
$LOAD_PATH << './lib'
require 'rubygems'
require 'sinatra'
require 'haml'
require 'sass'
require 'flickraw'
require 'digest/sha1'
require 'uri'
require 'cgi'
require 'fb_graph'
require 'image_helper.rb'

configure do
  set :public_folder, Proc.new { File.join(root, "static") }

  FlickRaw.api_key = ENV['FLICKR_API_KEY']
  FlickRaw.shared_secret = ENV['FLICKR_SECRET']
  flickr.access_token = ENV['FLICKR_ACCESS_TOKEN']
  flickr.access_secret = ENV['FLICKR_ACCESS_SECRET']

  set :fb_app_id, ENV['FB_APP_ID']
  set :fb_app_secret, ENV['FB_APP_SECRET']
end

get '/' do
  haml :index
end

post '/upload' do
  unless params['photo'] && (tempfile = params['photo'][:tempfile])
    redirect '/'
  end

  file_name = tempfile.path
  logo = logo_in(params[:color_scheme])

  photo = add_logo(file_name, logo)
  photo.write(file_name)
  photo_id = flickr.upload_photo file_name, :is_public => false

  redirect "/show/#{photo_id}"
end

get '/show/:photo_id' do
  haml :show, :locals => { :photo_url => photo_url(params[:photo_id]), :photo_id => params[:photo_id] }
end

get '/share/facebook/:photo_id' do
  client = FbGraph::Auth.new(settings.fb_app_id, settings.fb_app_secret).client
  client.redirect_uri = callback_url(params[:photo_id])
  redirect client.authorization_uri(:scope => [:publish_stream, :publish_actions])
end

get '/facebook_callback/:photo_id' do
  client = FbGraph::Auth.new(settings.fb_app_id, settings.fb_app_secret).client
  client.redirect_uri = callback_url(params[:photo_id])
  client.authorization_code = params[:code]
  token = client.access_token! :client_auth_body

  user = FbGraph::User.me(token)
  user.photo!(:url => photo_url(params[:photo_id]), :message => 'Israel Loves Iran')

  redirect "/show/#{params[:photo_id]}?shared_facebook=1"
end

get '/stylesheets/styles.css' do
  content_type 'text/css', :charset => 'utf-8'
  sass :styles
end

helpers do
  def callback_url(photo_id)
    'http://' + request.host_with_port + '/facebook_callback/' + photo_id
  end

  def photo_url(photo_id)
    info = flickr.photos.getInfo(:photo_id => photo_id)
    FlickRaw.url_b(info)
  end

  def logo_in(color_scheme)
    "static/images/logo-#{color_scheme}.png"
  end

  def share_to_tumblr_link(photo_url)
    "http://www.tumblr.com/share/photo?source=#{CGI.escape(photo_url)}" +
      "&caption=#{URI.escape("We Love Iran")}" +
      "&click_thru=#{CGI.escape(request.url)}"
  end

  def unique_filename
    Digest::SHA1.hexdigest("#{Time.now}#{Time.now.usec}")
  end
end

