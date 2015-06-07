require 'mongoid'
require 'mongoid_taggable'
require 'mime/types'
require 'uri'

class Image
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Taggable

  tags_separator ' '

  field :mime, type: String
  field :body, type: Moped::BSON::Binary
  field :title, type: String, default: 'no title'
  field :url, type: String, default: ''

  scope :recent, desc(:created_at)

  validate :validate_mime
  validates :title, length: { maximum: 256 }
  validate :validate_url
  validates :url, length: { maximum: 2056 }

  index({ created_at: 1 }, {})

  def validate_mime
    mime_type = MIME::Types[mime].first
    errors.add(:mime, 'is invalid') unless mime_type.media_type == 'image' && mime_type.registered?
  end

  def validate_url
    return if !url || url == ''
    uri = URI.parse(url)
    p uri
    %w(http https).include?(uri.scheme) or raise 'has invalid scheme'
  rescue
    errors.add(:url, $!.message)
  end

  def image_url
    "/images/#{_id}"
  end

  def to_html(base_url)
    if self.mime == 'image/gif' 
      %Q(<a href="#{self.url}"><div class="tags">#{self.tags}</div><img width="600px" src="#{base_url}#{self.image_url}"></a>)
    else
      %Q(<a href="#{self.url}"><div class="tags">#{self.tags}</div><img src="#{base_url}#{self.image_url}"></a>)
    end
  end
end
