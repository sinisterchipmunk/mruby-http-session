unless defined?(MRuby)
  MRUBY_VERSION = ENV['MRUBY_VERSION'] || "master"
  repository, dir = 'https://github.com/mruby/mruby.git', "tmp/mruby-#{MRUBY_VERSION}"
  build_args = ARGV

  Dir.mkdir 'tmp'  unless File.exist?('tmp')
  unless File.exist?(dir)
    system "git clone #{repository} #{dir}"
    chdir dir do
      system "git checkout #{MRUBY_VERSION}"
    end
  end

  exit system(%Q[cd #{dir}; MRUBY_CONFIG=#{File.expand_path __FILE__} rake #{build_args.join(' ')}])
end

MRuby::Build.new do |conf|
  toolchain :clang
  conf.enable_sanitizer "address,undefined"
  conf.gembox 'full-core'
  conf.gem File.expand_path(File.dirname(__FILE__))
  conf.gem github: 'sinisterchipmunk/mruby-polarssl'
  conf.enable_test
  conf.enable_debug
  conf.disable_lock
end
