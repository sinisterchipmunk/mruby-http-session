MRuby::Gem::Specification.new('mruby-http-session') do |spec|
  spec.license = 'MIT'
  spec.authors = 'sinisterchipmunk@gmail.com'
  spec.version = "0.0.1"

  spec.add_test_dependency 'mruby-print'
  spec.add_test_dependency 'mruby-env'
  spec.add_test_dependency 'mruby-fiber'
  spec.add_test_dependency 'mruby-enumerator'
  spec.add_test_dependency 'mruby-metaprog'
  spec.add_dependency 'mruby-polarssl', github: 'sinisterchipmunk/mruby-polarssl'
  spec.add_dependency 'mruby-socket'
  spec.add_dependency 'mruby-time'
  spec.add_dependency 'mruby-sprintf'
  spec.add_dependency 'mruby-object-ext'
  spec.add_dependency 'mruby-hash-ext'
  spec.add_dependency 'mruby-string-ext'
  spec.add_dependency 'mruby-errno'
end
