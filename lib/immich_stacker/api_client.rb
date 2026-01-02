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
      page = 1
      limit = 1000
      loop do
        response = @conn.post('search/metadata', {
          #originalFileName: 'IMG_1485', # NL: testing
          page: page,
          size: limit,
          withExif: true,
          withStacked: true
        })
        raise "Failed to fetch assets: #{response.status} #{response.body}" unless response.success?

        items = response.body['assets']['items']
        assets.concat(items)

        # NL: withStacked is not doing anything - items should have `stack` field, but don't
        # https://github.com/immich-app/immich/issues/16180
        #binding.break

        # NL: we're getting duplicates because the resultset is not strictly ordered, and assets are returning
        # in a different order page to page. This causes one set of files with the same originalFileName and date/time
        # to randomly change order. This causes there to be duplicates in `assets`, and one of the files to be missing.

        break if items.empty? || items.size < limit
        page += 1
      end
      assets
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
