module ImmichStacker
  class Operation
    def initialize(config)
      @field = config['field']
      @pattern = config['pattern']
      @index = config['index'] || 0
    end

    def evaluate(asset)
      val = asset.field(@field)
      return nil if val.nil?

      if @pattern
        match = val.to_s.match(@pattern)
        return nil unless match
        match[@index]
      else
        val
      end
    end
  end
end
