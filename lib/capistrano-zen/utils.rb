require 'capistrano-zen/base'

configuration = Capistrano::Configuration.respond_to?(:instance) ?
  Capistrano::Configuration.instance(:must_exist) :
  Capistrano.configuration(:must_exist)

configuration.load do
  before "deploy", "check:revision"
  before "deploy:migrations", "check:revision"
  before "deploy:cold", "check:revision"

  namespace :check do
    desc "Make sure local git is in sync with remote."
    task :revision do
      unless `git rev-parse #{branch}` == `git rev-parse origin/#{branch}`
        puts "WARNING: HEAD is not the same as origin/#{branch}"
        puts "Run `git push` to sync changes."
        exit
      end
    end
  end

  namespace :dev_lib do
    task :install do
      # nokogiri dependencies
      run "#{sudo} apt-get install libxslt-dev libxml2-dev"

      # paperclip dependencies
      run "#{sudo} apt-get install imagemagick"
    end
  end
end
