require 'mongoid'
require 'active_support'

namespace :db do
  namespace :mongoid do
    task :create_indexes, :environment do |t, args|
      ENV['MONGOID_ENV'] = args[:environment] || 'development'
      Mongoid.load!('config/mongoid.yml')

      Dir.glob('models/*.rb').each do |file|
        require_relative file
        klass = file[/\/(.+?)\.rb$/, 1].camelize.constantize
        next unless klass.ancestors.select{|c| c == Mongoid::Document}.size > 0
        klass.create_indexes
      end
    end
    task :migrate_body_to_content, :environment do |t, args|
      ENV['MONGOID_ENV'] = args[:environment] || 'development'
      Mongoid.load!('config/mongoid.yml')
      require_relative 'models/image'
      Image.all.each do |image|
        image.content = image.body if image.body
        image.body = nil
        image.save
      end
    end
  end
end
