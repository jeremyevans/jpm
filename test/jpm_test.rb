Dir.chdir(File.dirname(File.dirname(File.expand_path(__FILE__))))
ENV["JPM_DIR"] = File.join(File.dirname(File.expand_path(__FILE__)), '.jpm')
ENV["JPM_READ_PASS"] = "stdin"
ENV['MT_NO_PLUGINS'] = '1' # Work around stupid autoloading of plugins
ENV["EDITOR"] = "/usr/bin/touch"
require 'minitest/global_expectations/autorun'
require 'fileutils'
require 'open3'
JPM_DIR = "test/.jpm"

describe "jpm" do
  def jpm(*args, &block)
    print '.'
    Open3.popen3("./jpm", *args, &block)
  end

  def files(subdir)
    Dir["#{JPM_DIR}/#{subdir}/*"].sort.map{|f| File.basename(f)}
  end

  after do
    FileUtils.rm_r(JPM_DIR) if File.directory?(JPM_DIR)
  end

  it 'should display the usage on command or argument error' do
    [[], ['-x'], ['foo']].each do |args|
      jpm(*args) do |_,o,e,t|
        e.read.must_include "Password Manager"
        o.read.must_be_empty
        t.value.exitstatus.must_equal 1
      end
    end
  end

  it 'should display the usage on -h' do
    jpm('-h') do |_,o,e,t|
      o.read.must_include "Password Manager"
      e.read.must_be_empty
      t.value.exitstatus.must_equal 0
    end
  end

  it 'commands should work' do
    pass = "fooo"

    jpm('ls') do |_,o,e,t|
      o.read.must_be_empty
      e.read.must_equal "Missing openssl or signify secret, run jpm init\n"
      t.value.exitstatus.must_equal 1
    end

    jpm('init') do |i,o,e,t|
      i.puts pass
      i.close
      o.read.must_be_empty
      e.read.must_include "Generating a 4096 bit RSA private key"
      t.value.exitstatus.must_equal 0
    end
    files("private").must_equal %w"encrypt.key encrypt.pub signify.pub signify.sec"
    files("store").must_be_empty
    files("tmpstore").must_be_empty

    jpm('add', 'Foo') do |i,o,e,t|
      i.puts 'fiii'
      i.close
      o.read.must_match(/\ASigning .*\/Foo with .*\/signify\.sec/)
      e.read.must_include("signify: incorrect passphrase")
      t.value.exitstatus.must_equal 1
    end
    files("store").must_equal %w"Foo"
    files("tmpstore").must_be_empty

    jpm('sign', 'Foo') do |i,o,e,t|
      i.puts pass
      i.close
      o.read.must_be_empty
      e.read.must_be_empty
      t.value.exitstatus.must_equal 0
    end
    files("store").must_equal %w"Foo Foo.sig"
    files("tmpstore").must_be_empty

    jpm('rm', 'Foo') do |_,o,e,t|
      o.read.must_be_empty
      e.read.must_be_empty
      t.value.exitstatus.must_equal 0
    end
    files("store").must_be_empty

    File.write("test/.jpm/tmpstore/Foo", "bar\nbaz")
    jpm('add', 'Foo') do |i,o,e,t|
      i.puts pass
      i.close
      o.read.must_match(/\ASigning .*\/Foo with .*\/signify\.sec/)
      e.read.must_be_empty
      t.value.exitstatus.must_equal 0
    end
    files("store").must_equal %w"Foo Foo.sig"
    files("tmpstore").must_be_empty

    jpm('show', 'Foo') do |i,o,e,t|
      i.puts pass
      i.close
      o.read.sub("\r\n", "\n").must_equal "bar\nbaz"
      e.read.must_be_empty
      t.value.exitstatus.must_equal 0
    end

    jpm('ls') do |_,o,e,t|
      o.read.must_equal "Foo\n"
      e.read.must_be_empty
      t.value.exitstatus.must_equal 0
    end

    jpm('find', 'bar') do |_,o,e,t|
      o.read.must_be_empty
      e.read.must_be_empty
      t.value.exitstatus.must_equal 0
    end

    jpm('find', 'f.o') do |_,o,e,t|
      o.read.must_equal "Foo\n"
      e.read.must_be_empty
      t.value.exitstatus.must_equal 0
    end

    jpm('verify') do |_,o,e,t|
      o.read.must_be_empty
      e.read.must_be_empty
      t.value.exitstatus.must_equal 0
    end

    new_pass = 'fiii'
    jpm('rotate') do |i,o,e,t|
      i.puts pass
      sleep 0.1
      i.puts new_pass
      i.close
      o.read.must_match(/\ASigning .*\/tmpstore\/Foo with .*\/tmp\.signify\.sec/)
      e.read.must_include "Generating a 4096 bit RSA private key"
      t.value.exitstatus.must_equal 0
    end
    files("private").must_equal %w"encrypt.key encrypt.pub signify.pub signify.sec"
    files("store").must_equal %w"Foo Foo.sig"
    files("tmpstore").must_be_empty

    jpm('mv', 'Foo', 'Baz') do |_,o,e,t|
      o.read.must_be_empty
      e.read.must_be_empty
      t.value.exitstatus.must_equal 0
    end
    files("store").must_equal %w"Baz Baz.sig"

    jpm('show', 'Baz') do |i,o,e,t|
      i.puts new_pass
      i.close
      o.read.sub("\r\n", "\n").must_equal "bar\nbaz"
      e.read.must_be_empty
      t.value.exitstatus.must_equal 0
    end

    if ENV['DISPLAY']
      jpm('clip', 'Baz') do |i,o,e,t|
        i.puts new_pass
        i.close
        t.value.exitstatus.must_equal 0
      end
      `xclip -o`.must_equal "bar"
    end

    jpm('add', 'Bar/Baz') do |i,o,e,t|
      i.puts new_pass
      i.close
      o.read.must_be_empty
      e.read.must_include("invalid entry name")
      t.value.exitstatus.must_equal 1
    end
    files("store").must_equal %w"Baz Baz.sig"
    files("tmpstore").must_be_empty
  end
end
