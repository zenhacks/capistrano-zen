require 'capistrano-zen/base'

configuration = Capistrano::Configuration.respond_to?(:instance) ?
  Capistrano::Configuration.instance(:must_exist) :
  Capistrano.configuration(:must_exist)

configuration.load do
  namespace :nginx do
    desc "Install latest stable release of nginx"
    task :install, roles: :web do
      run "#{sudo} add-apt-repository ppa:nginx/stable"
      run "#{sudo} apt-get -y update"
      run "#{sudo} apt-get -y install nginx"
      run "#{sudo} rm -f /etc/nginx/sites-enabled/default"
    end

    namespace :setup do
      desc "Setup nginx configuration for unicorn application"
      task :unicorn, roles: :web do
        template "nginx_unicorn.erb", "/tmp/nginx_conf"
        run "#{sudo} mv /tmp/nginx_conf /etc/nginx/sites-available/#{application}"
        link
        restart
      end

      desc "Setup nginx configuration for static website"
      task :static, roles: :web do
        template "nginx_static.erb", "/tmp/nginx_conf"
        run "#{sudo} mv /tmp/nginx_conf /etc/nginx/sites-available/#{application}"
        link
        restart
      end

      desc "Setup nginx configuration for wordpress website"
      task :wordpress, roles: :web do
        template "nginx_wordpress.erb", "/tmp/nginx_conf"
        run "#{sudo} mv /tmp/nginx_conf /etc/nginx/sites-available/#{application}"
        link
        restart
      end

      desc "create symbolic link"
      task :link do
        run "#{sudo} rm /etc/nginx/sites-enabled/#{application}"
        run "#{sudo} ln -s /etc/nginx/sites-available/#{application}  /etc/nginx/sites-enabled/"
      end
    end

    %w[start stop restart reload].each do |command|
      desc "#{command} nginx"
      task command, roles: :web do
        run "#{sudo} service nginx #{command}"
      end
    end
  end
end
