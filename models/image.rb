class Image
  include Mongoid::Document
  include Mongoid::Timestamps

  field mime: String
  field body: Moped::BSON::Binary

  scope :recent, desc(:created_at)
end
