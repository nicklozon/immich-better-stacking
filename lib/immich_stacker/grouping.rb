module ImmichStacker
  class Grouping
    def initialize(config)
      @inclusion_ops = (config['inclusion_operations'] || []).map { |op| Operation.new(op) }
      @criteria_ops = (config['criteria_operations'] || []).map { |op| Operation.new(op) }
      @parent_ops = (config['parent_operations'] || []).map { |op| Operation.new(op) }
    end

    def matches_inclusion?(asset)
      @inclusion_ops.all? { |op| op.evaluate(asset) }
    end

    def grouping_key(asset)
      @criteria_ops.map { |op| op.evaluate(asset).to_s }.join('|')
    end

    def determine_parent(assets)
      # Loop files first, then operations.
      assets.each do |asset|
        @parent_ops.each do |op|
          return asset if op.evaluate(asset)
        end
      end
      # If no operation passes, use the last file in the group.
      assets.last
    end
  end
end
