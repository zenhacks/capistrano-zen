configuration = Capistrano::Configuration.respond_to?(:instance) ?
  Capistrano::Configuration.instance(:must_exist) :
  Capistrano.configuration(:must_exist)

configuration.load do

  namespace :dev_lib do
    task :install do
      # nokogiri dependencies
      run "#{sudo} apt-get install libxslt-dev libxml2-dev"

      # paperclip dependencies
      run "#{sudo} apt-get install imagemagick"
    end
  end

end
