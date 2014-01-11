class Tags < Array
  def initialize(tags)
    super((tags || '').split(Image.tags_separator))
  end

  def images
    self.length > 0 ? Image.tagged_with_all(self) : Image
  end

  def title_prefix
    self.length > 0 ? "#{self.join(Image.tags_separator)} - " : ''
  end

  def query_params
    self.length > 0 ? "?tags=#{self.join(Image.tags_separator)}" : ''
  end
end
