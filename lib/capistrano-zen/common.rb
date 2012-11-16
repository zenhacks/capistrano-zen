def _cset(name, *args, &block)
  unless exists?(name)
    set(name, *args, &block)
  end
end

def template(from, to)
  erb = File.read(File.expand_path("../tmpls/#{from}", __FILE__))
  upload StringIO.new(ERB.new(erb).result(binding)), to
end
