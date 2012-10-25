configuration = Capistrano::Configuration.respond_to?(:instance) ?
  Capistrano::Configuration.instance(:must_exist) :
  Capistrano.configuration(:must_exist)

configuration.load do
  _cset(:unicorn_user) { user }
  _cset(:unicorn_group) { group }
  _cset(:unicorn_pid) { "#{current_path}/tmp/pids/unicorn.pid" }
  _cset(:unicorn_config) { "#{shared_path}/config/unicorn.rb" }
  _cset(:unicorn_log) { "#{shared_path}/log/unicorn.log" }
  _cset(:unicorn_workers, 4)

  namespace :unicorn do
    desc "Setup Unicorn initializer and app configuration"
    task :setup, roles: :app do
      run "mkdir -p #{shared_path}/config"
      template "unicorn.rb.erb", unicorn_config
      template "unicorn_init.erb", "/tmp/unicorn_init"
      run "chmod +x /tmp/unicorn_init"
      run "#{sudo} mv /tmp/unicorn_init /etc/init.d/unicorn_#{application}"
      run "#{sudo} update-rc.d -f unicorn_#{application} defaults"
    end

    %w[start stop restart upgrade force-stop].each do |command|
      desc "#{command} unicorn"
      task command, roles: :app do
        run "service unicorn_#{application} #{command}"
      end
      after "deploy:#{command}", "unicorn:#{command}"
    end
  end
end
