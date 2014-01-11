require 'sinatra'
require 'mongoid'
require 'haml'
require 'mime/types'
require 'base64'

require_relative 'models/image'

set :public_folder, proc{ File.join(root, 'static') }

Mongoid.load!('config/mongoid.yml')

# 画像一覧
get '/' do
  @images = Image.recent
  haml :index
end

# 画像投稿エンドポイント
post '/images/new' do
  mime, base64 = params[:data_uri].scan(/^data:(.+);base64,(.+)$/).first

  mime_type = MIME::Types[mime].first
  halt 400, 'invalid mime' unless mime_type.media_type == 'image' && mime_type.registered?
  body = Base64.decode64(base64)

  image = Image.new({
    mime: mime,
    body: Moped::BSON::Binary.new(:generic, body),
  })
  halt 503, 'failed to save image' unless image.save
  redirect '/'
end

# 画像表示
get '/images/:id/show' do
  image = Image.find(params[:id])
  halt 404, 'image not found' unless image
  content_type image.mime
  image.body.to_s
end
