require 'faraday'
require 'faraday/retry'
require 'dotenv'
require 'json'
require 'pathname'

require_relative 'immich_stacker/configuration'
require_relative 'immich_stacker/api_client'
require_relative 'immich_stacker/asset'
require_relative 'immich_stacker/operation'
require_relative 'immich_stacker/grouping'
require_relative 'immich_stacker/stacker'

module ImmichStacker
  def self.run
    Dotenv.load(ENV['VARS_PATH'] || '.env')

    config = Configuration.new
    api_client = ApiClient.new(
      api_endpoint: config.api_endpoint,
      api_key: config.api_key
    )

    stacker = Stacker.new(
      configuration: config,
      api_client: api_client
    )

    stacker.run
  rescue StandardError => e
    puts "Error: #{e.message}"
    puts e.backtrace if ENV['DEBUG']
    exit 1
  end
end
