# -*- encoding: utf-8 -*-
Gem::Specification.new do |s|
  s.name = 'evt-consumer'
  s.version = '2.2.0.1'
  s.summary = 'Continuous subscription to a category and message dispatching to handlers'
  s.description = ' '

  s.authors = ['The Eventide Project']
  s.email = 'opensource@eventide-project.org'
  s.homepage = 'https://github.com/eventide-project/consumer'
  s.licenses = ['MIT']

  s.require_paths = ['lib']
  s.platform = Gem::Platform::RUBY
  s.required_ruby_version = '>= 2.4.0'

  files = Dir.glob('{lib}/**/*')

  files.reject! do |file|
    file.match?(/postgres/)
  end

  s.files = files

  s.bindir = 'bin'

  s.add_runtime_dependency 'ntl-actor'

  s.add_runtime_dependency 'evt-configure'
  s.add_runtime_dependency 'evt-poll'
  s.add_runtime_dependency 'evt-messaging'
  s.add_runtime_dependency 'evt-settings'

  s.add_development_dependency 'test_bench'
end
