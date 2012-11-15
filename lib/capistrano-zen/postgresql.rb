require 'capistrano-zen/base'
require 'yaml'

configuration = Capistrano::Configuration.respond_to?(:instance) ?
  Capistrano::Configuration.instance(:must_exist) :
  Capistrano.configuration(:must_exist)

configuration.load do

  _cset(:pg_config_path) { abort "[Error] posgtresql recipes need `pg_config_path` to find the database.yml file." }
  _cset(:pg_backup_path) { abort "[Error] posgtresql recipes need `pg_backup_path` to execute backups." }

  DB_FILE_PATH = "#{pg_config_path}/database.yml"
  DBCONFIG = YAML.load_file(DB_FILE_PATH)

  _cset(:psql_host) { DBCONFIG['production']['host'] }
  _cset(:psql_user) { DBCONFIG['production']['username'] }
  _cset(:psql_password) { DBCONFIG['production']['password'] }
  _cset(:psql_database) { DBCONFIG['production']['database'] }

  namespace :pg do
    desc "Install the latest stable release of psql."
    task :install, roles: :db, only: {primary: true} do
      run "#{sudo} add-apt-repository -y ppa:pitti/psql"
      run "#{sudo} apt-get -y update"
      run "#{sudo} apt-get -y install psql libpq-dev"
    end

    desc "Create a database for this application."
    task :init, roles: :db, only: { primary: true } do
      # reset the database and role
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
    end

    desc "Symlink the database.yml file into latest release"
    task :symlink, roles: :app do
      run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml"
    end

    desc "Dump the application's database to backup path."
    task :dump, roles: :db, only: { primary: true } do
      # ignore migrations / exclude ownership / clean restore
      run "pg_dump #{psql_database} -T '*migrations' -O -c -U #{psql_user} -h localhost | gzip > #{pg_backup_path}/#{application}-#{release_name}.sql.gz" do |channel, stream, data|
        puts data if data.length >= 3
        channel.send_data("#{psql_password}\n") if data.include? 'Password'
      end
    end
  end
end
