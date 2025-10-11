require "rake"

task :setup do
  sh "bundle config set --local path 'vendor/bundle'"
  sh "bundle install"
end

task :dev do
  sh %q{bundle exec rerun --pattern "**/*.{rb,js,yml,erb}" -- bundle exec puma -C puma.rb}
end

task :run do
  sh "bundle exec puma -C puma.rb"
end

task :lint do
  sh "bundle exec rubocop || true"
end

task :test do
  sh "bundle exec rspec"
end

task :clean do
  sh "rm -rf vendor .bundle tmp log 2>/dev/null || true"
end

task default: :run
