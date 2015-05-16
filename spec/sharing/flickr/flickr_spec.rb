require 'spec_helper'

describe "Flickr" do
  before(:each) do
    begin
      options = YAML.load_file('options.yml')
    rescue
      puts "Please create an options.yml file, based on options_example.yml"
      raise
    end

    flickr_options = options['flickr']
    @api_key = flickr_options['flickr_api_key']
    @api_secret = flickr_options['flickr_secret']

    FlickRaw.api_key = @api_key
    FlickRaw.shared_secret = @api_secret

  end

  describe "options parsing" do
    context "options" do
      it "can retrieve authentication credentials" do
        expect(@api_key).not_to be_nil
        expect(@api_secret).not_to be_nil
      end
    end
  end

  describe "authentication", :vcr do
    VCR.use_cassette 'flickr' do

      before(:each) do
        token = flickr.get_request_token
        @oauth_token = token["oauth_token"]
        @oauth_token_secret = token["oauth_token_secret"]
        expect(@oauth_token).not_to be nil
        expect(@oauth_token_secret).not_to be nil
      end

      context "authorisation" do
        it "can be authorised" do
          auth_url = flickr.get_authorize_url(@oauth_token, :perms => 'write')
          expect(auth_url).to_not be nil
        end
      end
    end
  end
end
