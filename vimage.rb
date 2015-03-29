require 'sinatra'
require 'mongoid'
require 'haml'
require 'base64'
require 'RMagick'
require 'will_paginate_mongoid'
require 'rss/maker'

require_relative 'models/image'
require_relative 'models/tags'

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
  @tags = Tags.new(params[:tags])

  @images = @tags.images.recent.paginate(page: page)
  haml :index
end

get '/images.rss' do
  @tags = Tags.new(params[:tags])
  @images = @tags.images.recent.limit(200)

  rss = RSS::Maker.make('2.0') do |rss|
    rss.channel.title = "#{@tags.title_prefix}vimage"
    rss.channel.description = 'images from vimage'
    rss.channel.link = "#{base_url}/#{@tags.query_params}"

    @images.each do |image|
      item = rss.items.new_item
      item.title = image.title
      item.link = image.url || "#{base_url}#{image.image_url}"
      item.guid.content = image._id
      item.guid.isPermaLink = false
      item.description = %Q(<div class="tags">#{image.tags}</div><img src="#{base_url}#{image.image_url}">)
      item.date = image.updated_at
    end
  end

  content_type 'application/xml'
  rss.to_s
end

# 画像投稿エンドポイント
post '/images/new' do
  # Decode
  body = Base64.decode64(params[:base64])

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
    title: params[:title],
    tags: params[:tags],
    url: params[:url],
  })
  halt 503, "failed to save image: #{image.errors.full_messages.join(', ')}" unless image.save

  # Destroy overflowed image
  EM::defer do
    Image.asc(:created_at).first.destroy while Image.count > 4000
  end

  redirect image.image_url
end

# 画像表示
get '/images/:id' do
  halt 403, 'invalid password' unless request.cookies['password'] == ENV['VIMAGE_PASSWORD']
  image = Image.find(params[:id])
  halt 404, 'image not found' unless image
  content_type image.mime
  image.body.to_s
end

# インチキ認証
post '/login' do
  response.set_cookie(:password, value: params[:password], expires: Time.new(2024))
  redirect '/'
end
