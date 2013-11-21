require 'securerandom'
require 'capistrano-zen/base'

configuration = Capistrano::Configuration.respond_to?(:instance) ?
  Capistrano::Configuration.instance(:must_exist) :
  Capistrano.configuration(:must_exist)

configuration.load do
  namespace :wordpress do
    desc "upload the configuration to remote server"
    task :config, roles: :web do
      template "wp-config.php.erb", "/tmp/wp-config.php"
      run "#{sudo} mv /tmp/wp-config.php #{deploy_to}/"
    end
  end
end

def random_salts
  SecureRandom.urlsafe_base64(60)
end
