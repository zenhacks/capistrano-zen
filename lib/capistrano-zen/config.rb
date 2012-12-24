require 'capistrano-zen/base'
require 'yaml'

configuration = Capistrano::Configuration.respond_to?(:instance) ?
  Capistrano::Configuration.instance(:must_exist) :
  Capistrano.configuration(:must_exist)

configuration.load do
  _cset(:config_path) { abort "[Error] config recipes need `config_path` to find the application.yml file." }

  namespace :config do
    desc "upload the application.yml file into the deploy environments"
    task :setup, roles: :app do
      upload "#{config_path}/application.yml", "#{shared_path}/config/application.yml"
    end

    desc "Symlink the database.yml file into latest release"
    namespace :db do
      task :symlink, roles: :app do
        run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml"
      end
    end

    desc "Symlink the application.yml file into latest release"
    namespace :env do
      task :symlink, roles: :app do
        run "ln -nfs #{shared_path}/config/application.yml #{release_path}/config/application.yml"
      end
    end
  end
end
