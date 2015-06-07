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
    rss.channel.link = "#{base_url}#{@tags.query_params}"

    @images.each do |image|
      item = rss.items.new_item
      item.title = image.title
      item.link = image.url || "#{base_url}#{image.image_url}"
      item.guid.content = image._id
      item.guid.isPermaLink = false
      item.description = image.to_html(base_url)
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
  mimg = Magick::ImageList.new.from_blob(body)
  if (mimg.size > 1) # animated
    body = mimg.to_blob
  else
    mimg = mimg.first
    mimg.resize_to_fit!(600, 600) if [mimg.columns, mimg.rows].any? {|n| n > 600}
    mimg.format = 'jpeg'
    body = mimg.to_blob {|i| i.quality = 60}
  end

  # Save
  image = Image.new({
    mime: mimg.mime_type,
    body: Moped::BSON::Binary.new(:generic, body),
    title: params[:title],
    tags: params[:tags],
    url: params[:url],
  })
  # MongoLabは容量制限を超えると保存に成功させたあと無言で勝手に削除するので注意！ストレージ全体の容量制限とは別に、ドキュメントあたり40kBの容量制限もある様子
  halt 503, "failed to save image: #{image.errors.full_messages.join(', ')}" unless image.save
  halt 503, "failed to save image truly: #{image.errors.full_messages.join(', ')}" unless Image.find(image.id)

  # Destroy overflowed image
  EM::defer do
    # MongoLabのSandboxプランで最大400MB
    # さらに裏では1ドキュメントあたり最大40kBの制限がある
    # 従って、 500000 / 40 = 12500ドキュメントあたりが限界値となる
    # 実際にはもろもろのデータが突っ込まれるので、要件を満たす範囲内で小さい値にしておく
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
