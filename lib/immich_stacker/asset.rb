module ImmichStacker
  class Asset
    attr_reader :id, :original_path, :directory, :filename, :extension, :exif_date, :stack_id

    def initialize(data)
      @id = data['id']
      @original_path = data['originalPath'] || ''
      @stack_id = data['stackId'] || (data['stack'] && data['stack']['id'])

      exif = data['exifInfo'] || {}
      @exif_date = exif['dateTimeOriginal']

      parse_path!
    end

    def stacked?
      !@stack_id.nil?
    end

    def field(name)
      case name.to_s
      when 'directory' then @directory
      when 'filename' then @filename
      when 'extension' then @extension
      when 'exif_date', 'DateTimeOriginal' then @exif_date
      when 'original_path' then @original_path
      else nil
      end
    end

    private

    def parse_path!
      return if @original_path.empty?

      path = Pathname.new(@original_path)
      @directory = path.dirname.to_s
      @extension = path.extname.delete_prefix('.')
      @filename = path.basename(path.extname).to_s # exclude extension
    end
  end
end
