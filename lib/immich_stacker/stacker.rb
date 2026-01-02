module ImmichStacker
  class Stacker
    def initialize(configuration:, api_client:)
      @config = configuration
      @api_client = api_client
    end

    def run
      puts "Fetching all assets from Immich..."
      raw_assets = @api_client.fetch_all_assets
      puts "Fetched #{raw_assets.size} assets."

      assets = raw_assets.map { |a| Asset.new(a) }
      unstacked_assets = assets.reject(&:stacked?)
      puts "#{unstacked_assets.size} assets are not yet stacked."

      @config.groupings.each_with_index do |grouping, index|
        puts "\nProcessing Grouping ##{index + 1}..."

        candidates = unstacked_assets.select { |a| grouping.matches_inclusion?(a) }
        puts "Found #{candidates.size} candidates matching inclusion criteria."

        groups = candidates.group_by { |a| grouping.grouping_key(a) }
                           .select { |_, assets| assets.size > 1 }
        puts "Formed #{groups.size} potential groups based on criteria."

        groups.each do |key, group_assets|
          parent = grouping.determine_parent(group_assets)
          children = group_assets.reject { |a| a.id == parent.id }

          puts "Group [#{key}]: Stacking #{children.size} assets onto parent #{parent.filename} (#{parent.id})"

          if @config.dry_run?
            puts "  [DRY RUN] Would create stack with primary: #{parent.id}, children: #{children.map(&:id)}"
          else
            @api_client.create_stack(
              primary_asset_id: parent.id,
              asset_ids: [parent.id] + children.map(&:id)
            )
          end
        end
      end

      puts "\nStacking process complete."
    end
  end
end
