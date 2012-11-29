require 'capistrano-zen/base'

configuration = Capistrano::Configuration.respond_to?(:instance) ?
  Capistrano::Configuration.instance(:must_exist) :
  Capistrano.configuration(:must_exist)

configuration.load do
  namespace :redis do
    desc "Install the stable relase of Redis"
    task :install do
      [
        "cd src",
        "git clone git://github.com/antirez/redis.git /tmp/redis",
        "cd /tmp/redis && git pull",
        "cd /tmp/redis && make clean",
        "cd /tmp/redis && make",
        "#{sudo} cp /tmp/redis/redis-benchmark /usr/bin/",
        "#{sudo} cp /tmp/redis/redis-cli /usr/bin/",
        "#{sudo} cp /tmp/redis/redis-server /usr/bin/",
        "#{sudo} cp /tmp/redis/redis.conf /etc/",
        "#{sudo} sed -i 's/daemonize no/daemonize yes/' /etc/redis.conf",
        "#{sudo} sed -i 's/^pidfile \/var\/run\/redis.pid/pidfile \/tmp\/redis.pid/' /etc/redis.conf"
      ].each {|cmd| run cmd}
    end
  end
end
