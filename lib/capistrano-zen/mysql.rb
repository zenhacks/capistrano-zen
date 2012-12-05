require 'capistrano-zen/base'
require 'yaml'

configuration = Capistrano::Configuration.respond_to?(:instance) ?
  Capistrano::Configuration.instance(:must_exist) :
  Capistrano.configuration(:must_exist)

configuration.load do

  _cset(:mysql_config_path) { abort "[Error] mysql recipes need `mysql_config_path` to find the database.yml file." }
  _cset(:mysql_backup_path) { abort "[Error] mysql recipes need `mysql_backup_path` to execute backups." }

  DB_FILE_PATH = "#{mysql_config_path}/database.yml"
  DBCONFIG = YAML.load_file(DB_FILE_PATH)

  _cset(:mysql_host) { DBCONFIG['production']['host'] }
  _cset(:mysql_user) { DBCONFIG['production']['username'] }
  _cset(:mysql_password) { DBCONFIG['production']['password'] }
  _cset(:mysql_database) { DBCONFIG['production']['database'] }

  _cset(:mysql_host_dev) { DBCONFIG['development']['host'] }
  _cset(:mysql_user_dev) { DBCONFIG['development']['username'] }
  _cset(:mysql_password_dev) { DBCONFIG['development']['password'] }
  _cset(:mysql_database_dev) { DBCONFIG['development']['database'] }

  namespace :mysql do
    desc "Install the latest stable release of MySQL."
    task :install, roles: :db, only: {primary: true} do
      root_password = Capistrano::CLI.password_prompt "Enter database password for 'root admin':"
      # install MySQL interactively
      # http://serverfault.com/questions/19367/scripted-install-of-mysql-on-ubuntu
      run "#{sudo} debconf-set-selections << 'mysql-server-5.1 mysql-server/root_password password #{root_password}'"
      run "#{sudo} debconf-set-selections << 'mysql-server-5.1 mysql-server/root_password_again password #{root_password}'"
      run "#{sudo} apt-get -y update"
      run "#{sudo} apt-get -y install mysql-server libmysqlclient-dev libmysql-ruby"
    end

    desc "Create a database for this application."
    task :init, roles: :db, only: { primary: true } do
      run %Q{#{sudo} -u postgres mysql -c "CREATE USER #{mysql_user} WITH PASSWORD '#{mysql_password}';"}
      run %Q{#{sudo} -u postgres mysql -c "CREATE DATABASE #{mysql_database} OWNER #{mysql_user};"}
    end

    desc "Reset the database and role for this application."
    task :reset, roles: :db, only: { primary: true } do
      # drop the database and role
      run %Q{#{sudo} -u postgres mysql -c "DROP DATABASE #{mysql_database};"}
      run %Q{#{sudo} -u postgres mysql -c "DROP ROLE #{mysql_user};"}
    end

    desc "Generate the database.yml configuration file."
    task :setup, roles: :app do
      run "mkdir -p #{shared_path}/config"
      template "postgresql.yml.erb", "#{shared_path}/config/database.yml"
      # init backup directory
      run "#{sudo} mkdir -p #{mysql_backup_path}"
      run "#{sudo} chown :#{group} #{mysql_backup_path}"
      run "#{sudo} chmod g+w #{mysql_backup_path}"
    end

    desc "Symlink the database.yml file into latest release"
    task :symlink, roles: :app do
      run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml"
    end

    desc "Dump the application's database to backup path."
    task :dump, roles: :db, only: { primary: true } do
      # ignore migrations / exclude ownership / clean restore
      run "pg_dump #{mysql_database} -T '*migrations' -O -c -U #{mysql_user} -h #{mysql_host} | gzip > #{mysql_backup_path}/#{application}-#{release_name}.sql.gz" do |channel, stream, data|
        puts data if data.length >= 3
        channel.send_data("#{mysql_password}\n") if data.include? 'Password'
      end
    end

    desc "Get the remote dump to local /tmp directory."
    task :get, roles: :db, only: { primary: true } do
      list_remote
      download "#{mysql_backup_path}/#{backup}", "/tmp/#{backup}", :once => true
    end

    desc "Put the local dump in /tmp to remote backups."
    task :put, roles: :db, only: { primary: true } do
      list_local
      upload "/tmp/#{backup}", "#{mysql_backup_path}/#{backup}"
    end

    namespace :restore do
      desc "Restore the remote database from dump files."
      task :remote, roles: :db, only: { primary: true } do
        list_remote
        run "gunzip -c #{mysql_backup_path}/#{backup} | mysql -d #{mysql_database} -U #{mysql_user} -h #{mysql_host}" do |channel, stream, data|
          puts data if data.length >= 3
          channel.send_data("#{mysql_password}\n") if data.include? 'Password'
        end
      end

      desc "Restore the local database from dump files."
      task :local do
        list_local
        run_locally "gunzip -c /tmp/#{backup} | mysql -d #{mysql_database_dev} -U #{mysql_user_dev} -h #{mysql_host_dev}"
      end
    end

    task :cleanup, roles: :db, only: { primary: true } do
      count = fetch(:pg_keep_backups, 10).to_i
      local_backups = capture("ls -xt #{mysql_backup_path}").split.reverse
      if count >= local_backups.length
        logger.important "no old backups to clean up"
      else
        logger.info "keeping #{count} of #{local_backups.length} backups"
        directories = (local_backups - local_backups.last(count)).map { |release|
          File.join(mysql_backup_path, release) }.join(" ")

        try_sudo "rm -rf #{directories}"
      end
    end

    # private tasks
    task :list_remote, roles: :db, only: { primary: true } do
      backups = capture("ls -x #{mysql_backup_path}").split.sort
      default_backup = backups.last
      puts "Available backups: "
      puts backups
      choice = Capistrano::CLI.ui.ask "Which backup would you like to choose? [#{default_backup}] "
      set :backup, choice.empty? ? backups.last : choice
    end

    task :list_local do
      backups = `ls -x /tmp | grep -e '.sql.gz$'`.split.sort
      default_backup = backups.last
      puts "Available local backups: "
      puts backups
      choice = Capistrano::CLI.ui.ask "Which backup would you like to choose? [#{default_backup}] "
      set :backup, choice.empty? ? backups.last : choice
    end
  end
end
