require 'capistrano-zen/base'

configuration = Capistrano::Configuration.respond_to?(:instance) ?
  Capistrano::Configuration.instance(:must_exist) :
  Capistrano.configuration(:must_exist)

configuration.load do
  namespace :redis, role: :app do
    desc "Install the latest release of Redis"
    task :install, roles: :app do
      run "#{sudo} add-apt-repository -y ppa:chris-lea/redis-server"
      run "#{sudo} apt-get -y update"
      run "#{sudo} apt-get -y install redis-server"
    end

    %w[start stop restart].each do |command|
      desc "#{command} redis"
      task command, roles: :web do
        run "#{sudo} service redis-server #{command}"
      end
    end
  end
end
