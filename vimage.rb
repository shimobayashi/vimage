require 'sinatra'
require 'mongoid'
require 'haml'
require 'base64'
require 'rmagick'
require 'will_paginate_mongoid'
require 'rss/maker'

require_relative 'models/image'

set :public_folder, proc{ File.join(root, 'static') }

Mongoid.load!('config/mongoid.yml')
WillPaginate.per_page = 20

helpers do
  def base_url
    "#{request.scheme}://#{request.host_with_port}"
  end
end

# 画像一覧
get '/' do
  page = [(params[:page] || '1')[/^(\d+)$/, 1].to_i, 1].max

  @images = Image.recent.paginate(page: page)
  haml :index
end

get '/images.rss' do
  @images = Image.recent.limit(200)

  rss = RSS::Maker.make('2.0') do |rss|
    rss.channel.title = 'vimage'
    rss.channel.description = 'images from vimage'
    rss.channel.link = "#{base_url}/"

    @images.each do |image|
      item = rss.items.new_item
      item.title = 'image'
      item.link = "#{base_url}#{image.url}"
      item.guid.content = image._id
      item.guid.isPermaLink = false
      item.description = %Q(<img src="#{base_url}#{image.url}">)
      item.date = image.updated_at
    end
  end

  content_type 'application/xml'
  rss.to_s
end

# 画像投稿エンドポイント
#TODO tagging
post '/images/new' do
  # Decode
  mime, base64 = params[:data_uri].scan(/^data:(.+);base64,(.+)$/).first
  body = Base64.decode64(base64)

  # Compress
  mimg = Magick::Image.from_blob(body).first
  mimg.resize_to_fit!(600, 600) if [mimg.columns, mimg.rows].any? {|n| n > 600}
  mimg.format = 'jpeg'
  mime = mimg.mime_type
  body = mimg.to_blob {|i| i.quality = 60}

  # Save
  image = Image.new({
    mime: mime,
    body: Moped::BSON::Binary.new(:generic, body),
    title: params[:title]
  })
  halt 503, "failed to save image: #{image.erros.join(', ')}" unless image.save
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
