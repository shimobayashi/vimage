require 'mime/types'

class Image
  include Mongoid::Document
  include Mongoid::Timestamps

  field mime: String
  field body: Moped::BSON::Binary

  scope :recent, desc(:created_at)

  validate :validate_mime

  def validate_mime
    mime_type = MIME::Types[mime].first
    errors.add(:mime, 'invalid mime') unless mime_type.media_type == 'image' && mime_type.registered?
  end

  def url
    "/images/#{_id}"
  end
end
