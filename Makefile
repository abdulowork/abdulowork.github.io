.PHONY: *

install_ruby:
	rbenv install --skip-existing

install_bundle: install_ruby
	rbenv exec bundle install

serve: install_bundle
	rbenv exec bundle exec jekyll serve
