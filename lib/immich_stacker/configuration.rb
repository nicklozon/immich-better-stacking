module ImmichStacker
  class Configuration
    attr_reader :api_key, :api_endpoint, :dry_run, :groupings

    def initialize
      @api_key = ENV['API_KEY']
      @api_endpoint = ENV['API_ENDPOINT']
      @dry_run = (ENV['DRY_RUN'] || 'false').to_s.downcase == 'true' || ENV['DRY_RUN'] == '1'
      @config_path = ENV['CONFIG_PATH'] || 'config.json'

      validate_env!
      load_config!
    end

    def dry_run?
      @dry_run
    end

    private

    def validate_env!
      raise "API_KEY is required" unless @api_key
      raise "API_ENDPOINT is required" unless @api_endpoint
    end

    def load_config!
      unless File.exist?(@config_path)
        raise "Configuration file not found: #{@config_path}"
      end

      data = JSON.parse(File.read(@config_path))

      # Support both a single grouping or an array of groupings
      if data['groupings']
        @groupings = data['groupings'].map { |g| Grouping.new(g) }
      else
        # Fallback for simple config
        @groupings = [Grouping.new(data)]
      end
    end
  end
end
