namespace :nginx do
  desc "Install latest stable release of nginx"
  task :install, roles: :web do
    run "#{sudo} add-apt-repository -y ppa:nginx/stable"
    run "#{sudo} apt-get -y update"
    run "#{sudo} apt-get -y install nginx"
  end

  desc "Setup nginx configuration for unicorn application"
  task :setup, roles: :web do
    template "nginx_unicorn.erb", "/tmp/nginx_conf"
    run "#{sudo} mv /tmp/nginx_conf /etc/nginx/sites-enabled/#{application}"
    run "#{sudo} rm -f /etc/nginx/sites-enabled/default"
    restart
  end

  %w[start stop restart reload].each do |command|
    desc "#{command} nginx"
    task command, roles: :web do
      run "#{sudo} service nginx #{command}"
    end
  end
end