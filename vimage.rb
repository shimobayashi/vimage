require 'sinatra'
require 'mongoid'
require 'haml'
require 'mime/types'
require 'base64'
require 'rmagick'

require_relative 'models/image'

set :public_folder, proc{ File.join(root, 'static') }

Mongoid.load!('config/mongoid.yml')

# 画像一覧
#TODO Paging
#TODO RSS
get '/' do
  @images = Image.recent
  haml :index
end

# 画像投稿エンドポイント
post '/images/new' do
  # Decode
  mime, base64 = params[:data_uri].scan(/^data:(.+);base64,(.+)$/).first
  mime_type = MIME::Types[mime].first
  halt 400, 'invalid mime' unless mime_type.media_type == 'image' && mime_type.registered?
  body = Base64.decode64(base64)

  # Compress
  mimg = Magick::Image.from_blob(body).first
  mimg.resize_to_fit!(500, 500) if [mimg.columns, mimg.rows].any? {|n| n > 500}
  mimg.format = 'jpeg'
  mime = mimg.mime_type
  body = mimg.to_blob {|i| i.quality = 60}

  # Save
  image = Image.new({
    mime: mime,
    body: Moped::BSON::Binary.new(:generic, body),
  })
  halt 503, 'failed to save image' unless image.save
  redirect '/'
end

# 画像表示
#TODO auth
get '/images/:id' do
  image = Image.find(params[:id])
  halt 404, 'image not found' unless image
  content_type image.mime
  image.body.to_s
end
