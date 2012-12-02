# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'kindle_strip/version'

Gem::Specification.new do |gem|
  gem.name          = "kindle_strip"
  gem.version       = KindleStrip::VERSION
  gem.authors       = ["Ueda Satoshi"]
  gem.email         = ["gunyoki@gmail.com"]
  gem.description   = %q{Strip SRCS records from .mobi}
  gem.summary       = %q{Amazon kindlegen generates .mobi file and adds a copy of the source files. It doubles the file size. This script strips unwanted payload.}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
