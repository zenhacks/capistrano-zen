require 'capistrano-zen/base'
require 'yaml'

configuration = Capistrano::Configuration.respond_to?(:instance) ?
  Capistrano::Configuration.instance(:must_exist) :
  Capistrano.configuration(:must_exist)

configuration.load do

  _cset(:db_config_path) { abort "[Error] posgtresql recipes need `db_config_path` to find the database.yml file." }
  _cset(:db_backup_path) { abort "[Error] posgtresql recipes need `db_backup_path` to execute backups." }

  DB_FILE_PATH = "#{db_config_path}/database.yml"
  DBCONFIG = YAML.load_file(DB_FILE_PATH)

  _cset(:psql_host) { DBCONFIG['production']['host'] }
  _cset(:psql_user) { DBCONFIG['production']['username'] }
  _cset(:psql_password) { DBCONFIG['production']['password'] }
  _cset(:psql_database) { DBCONFIG['production']['database'] }

  _cset(:psql_host_dev) { DBCONFIG['development']['host'] }
  _cset(:psql_user_dev) { DBCONFIG['development']['username'] }
  _cset(:psql_password_dev) { DBCONFIG['development']['password'] }
  _cset(:psql_database_dev) { DBCONFIG['development']['database'] }

  namespace :pg do
    desc "Install the latest stable release of PostgreSQL."
    task :install, roles: :db, only: {primary: true} do
      run "#{sudo} add-apt-repository -y ppa:pitti/postgresql"
      run "#{sudo} apt-get -y update"
      run "#{sudo} apt-get -y install postgresql libpq-dev"
    end

    desc "Create a database for this application."
    task :init, roles: :db, only: { primary: true } do
      run %Q{#{sudo} -u postgres psql -c "CREATE USER #{psql_user} WITH PASSWORD '#{psql_password}';"}
      run %Q{#{sudo} -u postgres psql -c "CREATE DATABASE #{psql_database} OWNER #{psql_user};"}
    end

    desc "Reset the database and role for this application."
    task :reset, roles: :db, only: { primary: true } do
      # drop the database and role
      run %Q{#{sudo} -u postgres psql -c "DROP DATABASE #{psql_database};"}
      run %Q{#{sudo} -u postgres psql -c "DROP ROLE #{psql_user};"}
    end

    desc "Generate the database.yml configuration file."
    task :setup, roles: :app do
      run "mkdir -p #{shared_path}/config"
      template "postgresql.yml.erb", "#{shared_path}/config/database.yml"
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
      # ignore migrations / exclude ownership / clean restore
      run "pg_dump #{psql_database} -T '*migrations' -O -c -U #{psql_user} -h #{psql_host} | gzip > #{db_backup_path}/#{application}-#{release_name}.sql.gz" do |channel, stream, data|
        puts data if data.length >= 3
        channel.send_data("#{psql_password}\n") if data.include? 'Password'
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
        run "gunzip -c #{db_backup_path}/#{backup} | psql -d #{psql_database} -U #{psql_user} -h #{psql_host}" do |channel, stream, data|
          puts data if data.length >= 3
          channel.send_data("#{psql_password}\n") if data.include? 'Password'
        end
      end

      desc "Restore the local database from dump files."
      task :local do
        list_local
        run_locally "gunzip -c /tmp/#{backup} | psql -d #{psql_database_dev} -U #{psql_user_dev} -h #{psql_host_dev}"
      end
    end

    task :cleanup, roles: :db, only: { primary: true } do
      count = fetch(:pg_keep_backups, 10).to_i
      local_backups = capture("ls -xt #{db_backup_path}").split.reverse
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
      backups = capture("ls -x #{db_backup_path}").split.sort
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
