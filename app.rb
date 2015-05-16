#!/usr/bin/env ruby
$LOAD_PATH << 'lib'
require 'rubygems'
require 'sinatra'
require 'haml'
require 'sass'
require 'helpers/application_helper'
require 'helpers/image_helper'
require 'helpers/twitter_helper'
require 'helpers/url_helper'
require 'YAML'
require 'flickraw'

configure do
  enable :sessions
  set :root, File.dirname(__FILE__)
  set :server, 'webrick'

  set :public_folder, Proc.new { File.join(root, "static") }

  options = YAML.load_file("options.yml")
  flickr_options = options['flickr']
  flickr_api_key = flickr_options['flickr_api_key']
  flickr_secret = flickr_options['flickr_secret']

  set :flickr_api_key,        flickr_api_key
  set :flickr_secret,         flickr_secret

  FlickRaw.api_key = flickr_api_key
  FlickRaw.shared_secret = flickr_secret

  token = flickr.get_request_token

  set :flickr_access_token,  token["oauth_token"]
  set :flickr_access_secret,  token["oauth_token_secret"]

  set :fb_app_id, ENV['FB_APP_ID']
  set :fb_app_secret, ENV['FB_APP_SECRET']
end

configure :production do
  require 'newrelic_rpm'
end

get '/' do
  haml :index
end

post '/upload_from_mobile' do
  tempfile = params['photo'][:tempfile]
  file_name = tempfile.path

  resize(file_name)

  photo_id = flickr.upload file_name
  flickr.set_coordinates(photo_id, params[:latitude], params[:longitude])

  status(200)
end

post '/upload' do
  unless is_an_image? params[:photo]
    session[:error] = "Please, upload an image"
    redirect '/'
  end

  tempfile = params['photo'][:tempfile]
  file_name = tempfile.path

  user_img = resize(file_name)

  photo = add_logo(user_img, params[:color_scheme])
  photo.write(file_name)

  photo_id = flickr.upload file_name
  session['set_coordinates'] = true

  redirect "/show/#{photo_id}"
end

get '/show/:photo_id' do
  haml :show, :locals => { :photo_url => flickr.photo_url(params[:photo_id]),
                           :photo_id => params[:photo_id],
                           :set_coordinates => session['set_coordinates'] }
end

post '/coordinates/:photo_id/:latitude/:longitude' do
  flickr.set_coordinates(params[:photo_id], params[:latitude], params[:longitude])
end

get '/share/facebook/:photo_id' do
  redirect facebook.authorization_url(facebook_callback_url(params[:photo_id]))
end

get '/callback/facebook/:photo_id' do
  photo = flickr.photo_url(params[:photo_id])
  callback = facebook_callback_url(params[:photo_id])
  facebook.share_photo(photo, 'I love Iranians. Do you? Join me at http://www.weloveiran.org', params[:code], callback)
  session[:success] = "Your picture was posted on your Facebook profile."
  redirect "/show/#{params[:photo_id]}"
end

get '/max_width' do
  content_type :json
  max_width_for(params[:width].to_i, params[:height].to_i, params[:banner_name]).to_json
end

get '/stylesheets/styles.css' do
  content_type 'text/css', :charset => 'utf-8'
  sass :styles
end
