require 'capistrano-zen/base'

configuration = Capistrano::Configuration.respond_to?(:instance) ?
  Capistrano::Configuration.instance(:must_exist) :
  Capistrano.configuration(:must_exist)

configuration.load do
  _cset :ruby_version, "1.9.3-p194"
  _cset :rbenv_bootstrap, "bootstrap-ubuntu-12-04"
  _cset(:root_password) { Capistrano::CLI.password_prompt "Root Password: " }

  # https://github.com/fesplugas/rbenv-installer
  namespace :rbenv do
    desc "Install rbenv, Ruby, and the Bundler gem"
    task :install, roles: :app do
      run "#{sudo} apt-get -y install curl git-core"
      run "curl -L https://raw.github.com/fesplugas/rbenv-installer/master/bin/rbenv-installer | bash"
      # FIXME run command to change download path to taobao
      bashrc = <<-BASHRC
  if [ -d $HOME/.rbenv ]; then
  export PATH="$HOME/.rbenv/bin:$PATH"
  eval "$(rbenv init -)"
  fi
  BASHRC
      put bashrc, "/tmp/rbenvrc"
      run "cat /tmp/rbenvrc ~/.bashrc > ~/.bashrc.tmp"
      run "mv ~/.bashrc.tmp ~/.bashrc"
      run "rm /tmp/rbenvrc"
      run "rbenv #{rbenv_bootstrap}" do |channel, stream, data|
        puts data if data.length >= 3
        channel.send_data("#{root_password}\n") if data.include? 'password'
      end
      run "rbenv install #{ruby_version}"
      run "rbenv global #{ruby_version}"
    end

    task :patch, roles: :app do
      # the performance patch
      # https://gist.github.com/1688857?utm_source=rubyweekly&utm_medium=email
      run "#{sudo} apt-get install autoconf"
      case "#{ruby_version}"
      when "1.9.3-p194"
        run "curl https://raw.github.com/gist/1688857/rbenv.sh | sh ; rbenv global 1.9.3-p194-perf"
      when "1.9.3-p286"
        run "curl https://raw.github.com/gist/3885178/rbenv.sh | sh ; rbenv global 1.9.3-p286-perf"
      end
      run "gem install bundler --no-ri --no-rdoc"
      run "rbenv rehash"
    end
    after "rbenv:install", "rbenv:patch"
  end
end
