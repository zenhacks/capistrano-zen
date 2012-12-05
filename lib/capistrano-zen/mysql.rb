require 'capistrano-zen/base'
require 'yaml'

configuration = Capistrano::Configuration.respond_to?(:instance) ?
  Capistrano::Configuration.instance(:must_exist) :
  Capistrano.configuration(:must_exist)

configuration.load do

  _cset(:db_config_path) { abort "[Error] mysql recipes need `db_config_path` to find the database.yml file." }
  _cset(:db_backup_path) { abort "[Error] mysql recipes need `db_backup_path` to execute backups." }

  DB_FILE_PATH = "#{db_config_path}/database.yml"
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
    desc "Install the latest stable release of MySQL with root password."
    task :install, roles: :db, only: {primary: true} do
      root_password = Capistrano::CLI.password_prompt "Enter database password for 'root':"
      # install MySQL interactively
      # http://serverfault.com/questions/19367/scripted-install-of-mysql-on-ubuntu
      run "#{sudo} debconf-set-selections << 'mysql-server-5.5 mysql-server/root_password password #{root_password}'"
      run "#{sudo} debconf-set-selections << 'mysql-server-5.5 mysql-server/root_password_again password #{root_password}'"
      run "#{sudo} apt-get -y update"
      run "#{sudo} apt-get -y install mysql-server libmysqlclient-dev libmysql-ruby"
    end

    desc "Create a database for this application."
    task :init, roles: :db, only: { primary: true } do
      sql = <<-SQL
      CREATE DATABASE #{mysql_database};
      GRANT ALL PRIVILEGES ON #{mysql_database}.* TO #{mysql_user}@localhost IDENTIFIED BY '#{mysql_password}';
      SQL

      run_sql(sql)
    end

    desc "Reset the database and role for this application."
    task :reset, roles: :db, only: { primary: true } do
      # drop the database and role
      sql = <<-SQL
      DROP USER #{mysql_user}@localhost;
      DROP DATABASE IF EXISTS #{mysql_database};
      SQL

      run_sql(sql)
    end

    desc "Generate the database.yml configuration file."
    task :setup, roles: :app do
      run "mkdir -p #{shared_path}/config"
      template "mysql.yml.erb", "#{shared_path}/config/database.yml"
      # init backup directory
      run "#{sudo} mkdir -p #{db_backup_path}"
      run "#{sudo} chown :#{group} #{db_backup_path}"
      run "#{sudo} chmod g+w #{db_backup_path}"
    end

    desc "Symlink the database.yml file into latest release"
    task :symlink, roles: :app do
      run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml"
    end

    desc "Dump the application's database to backup path."
    task :dump, roles: :db, only: { primary: true } do
      run "mysqldump -u #{mysql_user} -p --host=#{mysql_host} #{mysql_database} --add-drop-table | gzip > #{db_backup_path}/#{application}-#{release_name}.mysql.sql.gz" do |channel, stream, data|
        puts data if data.length >= 3
        channel.send_data("#{mysql_password}\n") if data =~ /password/
      end
    end

    desc "Get the remote dump to local /tmp directory."
    task :get, roles: :db, only: { primary: true } do
      list_remote
      download "#{db_backup_path}/#{backup}", "/tmp/#{backup}", :once => true
    end

    desc "Put the local dump in /tmp to remote backups."
    task :put, roles: :db, only: { primary: true } do
      list_local
      upload "/tmp/#{backup}", "#{db_backup_path}/#{backup}"
    end

    namespace :restore do
      desc "Restore the remote database from dump files."
      task :remote, roles: :db, only: { primary: true } do
        list_remote
        run "gunzip -c #{db_backup_path}/#{backup} | mysql -u #{mysql_user} -p -h #{mysql_host} #{mysql_database} " do |channel, stream, data|
          puts data if data.length >= 3
          channel.send_data("#{mysql_password}\n") if data =~ /password/
        end
      end

      desc "Restore the local database from dump files."
      task :local do
        list_local
        run_locally "gunzip -c /tmp/#{backup} | mysql -u -p #{mysql_user_dev} -h #{mysql_host_dev}" do |channel, stream, data|
          puts data if data.length >= 3
          channel.send_data("#{mysql_password}\n") if data =~ /password/
        end
      end
    end

    task :cleanup, roles: :db, only: { primary: true } do
      count = fetch(:pg_keep_backups, 10).to_i
      local_backups = capture("ls -xt #{db_backup_path} | grep mysql").split.reverse
      if count >= local_backups.length
        logger.important "no old backups to clean up"
      else
        logger.info "keeping #{count} of #{local_backups.length} backups"
        directories = (local_backups - local_backups.last(count)).map { |release|
          File.join(db_backup_path, release) }.join(" ")

        try_sudo "rm -rf #{directories}"
      end
    end

    # private tasks
    task :list_remote, roles: :db, only: { primary: true } do
      backups = capture("ls -x #{db_backup_path} | grep mysql").split.sort
      default_backup = backups.last
      puts "Available backups: "
      puts backups
      choice = Capistrano::CLI.ui.ask "Which backup would you like to choose? [#{default_backup}] "
      set :backup, choice.empty? ? backups.last : choice
    end

    task :list_local do
      backups = `ls -x /tmp | grep -e '.sql.gz$' | grep mysql`.split.sort
      default_backup = backups.last
      puts "Available local backups: "
      puts backups
      choice = Capistrano::CLI.ui.ask "Which backup would you like to choose? [#{default_backup}] "
      set :backup, choice.empty? ? backups.last : choice
    end

    def run_sql(sql)
      run "mysql -u root -p --execute=\"#{sql}\"" do |channel, stream, data|
        if data =~ /^Enter password:/
          pass = Capistrano::CLI.password_prompt "Enter database password for 'root':"
          channel.send_data "#{pass}\n"
        end
      end
    end
  end
end
