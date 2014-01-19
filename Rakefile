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
  end
end
