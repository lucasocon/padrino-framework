ENV['PADRINO_ENV'] = 'test'
PADRINO_ROOT = File.dirname(__FILE__) unless defined? PADRINO_ROOT

require File.expand_path('../../../load_paths', __FILE__)
require 'minitest/spec'
require 'minitest/autorun'
require 'rack/test'
require 'uuid'
require 'rack'
require 'mocha'
require 'thor/group'
require 'padrino-core/support_lite' unless defined?(SupportLite)
require 'padrino-admin'

Padrino::Generators.load_components!

module Kernel
  # Silences the output by redirecting to stringIO
  # silence_logger { ...commands... } => "...output..."
  def silence_logger(&block)
    $stdout = $stderr = log_buffer = StringIO.new
    block.call
    $stdout = STDOUT
    $stderr = STDERR
    log_buffer.string
  end
  alias :silence_stdout :silence_logger

  def load_fixture(file)
    Object.send(:remove_const, :Account)  if defined?(Account)
    Object.send(:remove_const, :Category) if defined?(Category)
    file += ".rb" if file !~ /.rb$/
    silence_stdout { load File.join(File.dirname(__FILE__), "fixtures", file) }
  end
end

class Class
  # Allow assertions in request context
  include MiniTest::Assertions
end

class MiniTest::Spec
  class << self
    alias :setup :before unless defined?(Rails)
    alias :teardown :after unless defined?(Rails)
    alias :should :it
    alias :context :describe
  end
  alias :assert_no_match  :refute_match
  alias :assert_not_nil   :refute_nil
  alias :assert_not_equal :refute_equal
  def assert_nothing_raised(&block)
    block.call
  end
  def self.should_eventually(desc)
    it("should eventually #{desc}") { skip("Should eventually #{desc}") }
  end

  include Rack::Test::Methods

  # Sets up a Sinatra::Base subclass defined with the block
  # given. Used in setup or individual spec methods to establish
  # the application.
  def mock_app(base=Padrino::Application, &block)
    @app = Sinatra.new(base, &block)
    @app.send :include, MiniTest::Assertions
    @app.register Padrino::Helpers
  end

  def app
    Rack::Lint.new(@app)
  end

  # generate(:admin_app, "-r=#{@apptmp}/sample_project")
  def generate(name, *params)
    "Padrino::Generators::#{name.to_s.camelize}".constantize.start(params)
  end

  # Assert_file_exists('/tmp/app')
  def assert_file_exists(file_path)
    assert File.exist?(file_path), "File at path '#{file_path}' does not exist!"
  end

  # Assert_no_file_exists('/tmp/app')
  def assert_no_file_exists(file_path)
    assert !File.exist?(file_path), "File should not exist at path '#{file_path}' but was found!"
  end

  # Asserts that a file matches the pattern
  def assert_match_in_file(pattern, file)
    File.exist?(file) ? assert_match(pattern, File.read(file)) : assert_file_exists(file)
  end

  def assert_no_match_in_file(pattern, file)
    File.exists?(file) ? assert_no_match(pattern, File.read(file)) : assert_file_exists(file)
  end

  # Delegate other missing methods to response.
  def method_missing(name, *args, &block)
    if response && response.respond_to?(name)
      response.send(name, *args, &block)
    else
      super(name, *args, &block)
    end
  end

  alias :response :last_response
end
