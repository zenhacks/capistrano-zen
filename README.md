## What Capistrano::Zen Is?
`Capistrano-zen` is **a collection of capistrano recipes** to install and manage various services on production machine powered by Ubuntu. The current tested environment is Ubuntu 12.04LTS.

It provides installation and management recipes for the following service:
- nginx
  - with config templates for rails app
- nodejs
- postgresql
- unicorn (integrated with a nginx/railsapp)
- rbenv

The upcoming recipes include:
- nginx
  - global config template
  - static website template
- shorewall
- vsftp
- php-fpm
- mysql
- mongodb
- redis

`capistrano-zen` is extracted from the deployment procedure at [zenhacks.org](zenhacks.org) for a Rails application so it is designed to work with the structure of a rails application. But most recipes are independent and future development will detach general recipes from a rails application.

## What Capistrano::Zen isn't?
`capistrano-zen` only provides recipes of tasks, it doesn't handle:

- the application dependencies
- the logic of deployment logic
- the server settings and configuration

You will need to declare those in your own capistrano config file such as `Capfile` or `config/deploy.rb`.

The gem includes some sample files to start with `Capfile-rails.sample`.

## Installation

Add this line to your application's Gemfile:

    gem 'capistrano-zen'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install capistrano-zen

## Dependencies
`capistrano-zen` uses `python-software-properties` to ease ppa source addition. You could install it with  use `python-software-properties` to ease ppa source addition. You could install it from your local machine with 

    cap deploy:install

Or install it mannually with 

    sudo apt-get install python-software-properties

## Usage

To load a set of recipes, require them in your `Capfile` with:

    require 'capistrano-zen/nginx'

You could verify the load is successful with:

    cap -T

## Recipes
Here is the recipes included in this gem:

- nginx
  - with config templates for rails app
- nodejs
- postgresql
- unicorn (integrated with a nginx/railsapp)
- rbenv

### Nginx
Default role: `web`

Configuration variables: none

Tasks:
- `nginx:install` installs the lastest release from the ppa `ppa:nginx/stable`.
- `nginx:start/stop/reload` maps to `sudo service nginx start/stop/reload` on the remote machine.
- `nginx:setup` generates a nginx site configuration for a rails app runs with `unicorn` through unix socket.

### NodeJS
Default role: `app`

Configuration variables: none

Tasks:
- `nodejs:install` installs `node` and `npm` from the `ppa:chris-lea/node.js`.

The ppa comes from [official wiki](https://github.com/joyent/node/wiki/Installing-Node.js-via-package-manager).

### Rbenv
It uses the [rbenv installer](https://github.com/fesplugas/rbenv-installer) to create a `ruby` environment.

Default role: `app`

Configuration variables:
- `ruby_version` indicates the ruby version installed.
- `rbenv_bootstrap` indicates the ubuntu version to install the rbenv bootstrap.

Tasks:
- `rbenv:install` installs `rbenv`, setups configuration in `~/.bashrc` and installs `ruby` with `ruby_version`
- `rbenv:patch` autoruns a ruby patch to enhance performance. [more info](https://gist.github.com/1688857?utm_source=rubyweekly&utm_medium=email)

### PostgreSQL
Currently, postgresql configuration is tightly attached to a rails application, it depends on the `config/database.yml` to setup remote server.

Default role: `db`

Configuration variables:
- `pg_config_path` the path for the `database.yml` file, the recipe reads from it to create database and generate remote `database.yml`. If you are using this recipe out of Rails application, store your configuration in a `config/database.yml`. 
- `pg_backup_path` the path to store database dumps.

Tasks:
- `pg:install` installs `postgresql` and `libpg-dev` from `ppa:pitti/postgresql`.
- `pg:reset` drops the databases and roles with the same names as in the application.
- `pg:init` generates roles and databases for the rails application.
- `pg:setup` generates remote `database.yml` based on local `database.yml`'s `production` settings.
- `pg:symlink` creates symbolic for the `database.yml` in the release.
- `pg:dump` dumps and compresses the application database, store them in the `pg_backup_path`.

### Unicorn
This recipes setup unicorn configuration based on current rails application, and generate a `init.d` control scripts to manage the service.
Default role: `app`

Configuration variables: 
- `unicorn_user` the user to run unicorn process, default to the same user as remote login user.
- `unicorn_group` the group to run unicorn process.
- `unicorn_pid` the path for the `unicorn.pid` file, default to the `current/tmp/pids/unicorn.pid`.
- `unicorn_config` the path to put the unicorn config file, default to `shared/config/unicorn.rb`.
- `unicorn_log` the path to put the unicorn log file, default to `shared/log/unicorn.log`.
- `unicorn_workers` the number of unicorn workers, default to 4.

Tasks: 
- `unicorn:setup` generate `unicorn.rb` config file and register `service` with `unicorn_init`.
- `unicorn:start/stop/restart/upgrade/force-stop` maps to remote `service unicorn start/stop/restart/upgrade/force-stop`. Details is in `/tmpls/unicorn_init.rb`

### Utils
- `check:revision` autoruns before any deployment tasks. It compares the local and remote master branch head to make sure remote master branch are up-to-date.
- `dev_lib:install` install libraries on which some gems depend such as `nokogiri` or `paperclip`.

## Get Started with Capistrano
The [wiki page](https://github.com/capistrano/capistrano/wiki) of `capistrano` has good resources to make you up to speed.
[Railscasts](http://railscasts.com/episodes?utf8=%E2%9C%93&search=capistrano) also has a good coverage for this tool.

## TODO
- make configuration rails-less
- add more recipes
