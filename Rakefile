require "rake"

desc "Run tests"
task "test" do
  sh "#{FileUtils::RUBY} -w #{'-W:strict_unused_block' if RUBY_VERSION >= '3.4'} test/jpm_test.rb"
end

task :default=>:test
