module ImmichStacker
  class ApiClient
    def initialize(api_endpoint:, api_key:)
      @api_endpoint = api_endpoint.chomp('/')
      @api_key = api_key

      @conn = Faraday.new(url: @api_endpoint) do |f|
        f.request :json
        f.response :json
        f.headers['x-api-key'] = @api_key
        f.request :retry, max: 3, interval: 0.05,
                         interval_randomness: 0.5, backoff_factor: 2,
                         exceptions: [Faraday::ConnectionFailed, Faraday::TimeoutError]
        f.adapter Faraday.default_adapter
      end
    end

    def fetch_all_assets
      assets = []
      limit = 1000
      params = {
        size: limit,
        withExif: true,
        withStacked: true,
        order: 'asc'
      }

      # NL: withStacked is not doing anything - items should have `stack` field, but doesn't
      # https://github.com/immich-app/immich/issues/16180

      loop do
        response = @conn.post('search/metadata', params)
        raise "Failed to fetch assets: #{response.status} #{response.body}" unless response.success?

        items = response.body['assets']['items']
        assets.concat(items)

        break if items.empty? || items.size < limit

        params[:takenAfter] = items.last['fileCreatedAt']
      end

      # De-duplicate assets by ID since takenAfter inclusion causes duplicates
      assets.uniq { |a| a['id'] }
    end

    def create_stack(primary_asset_id:, asset_ids:)
      # Endpoint: POST /stacks
      # Body: { "primaryAssetId": "uuid", "assetIds": ["uuid1", "uuid2"] }
      response = @conn.post('stacks', {
        primaryAssetId: primary_asset_id,
        assetIds: asset_ids
      })

      unless response.success?
        puts "Failed to create stack for #{primary_asset_id}: #{response.status} #{response.body}"
        return nil
      end

      response.body
    end
  end
end
