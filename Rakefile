require "rake"

desc "Run tests"
task "test" do
  sh "#{FileUtils::RUBY} -w test/jpm_test.rb"
end

task :default=>:test
