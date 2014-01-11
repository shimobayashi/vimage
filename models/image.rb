require 'mime/types'

class Image
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Taggable

  tags_separator ' '

  field :mime, type: String
  field :body, type: Moped::BSON::Binary
  field :title, type: String, default: 'no title'

  scope :recent, desc(:created_at)

  validate :validate_mime
  validates :title, length: { maximum: 256 }

  def validate_mime
    mime_type = MIME::Types[mime].first
    errors.add(:mime, 'invalid mime') unless mime_type.media_type == 'image' && mime_type.registered?
  end

  def url
    "/images/#{_id}"
  end
end
