# frozen_string_literal: true

require 'tempfile'

class EvalError < StandardError
  def initialize(msg) 
    super 
  end
end

class SafeRuby
  DEFAULTS = { timeout: 5,
               raise_errors: true }

  def initialize(code, options={})
    options = DEFAULTS.merge(options)

    @code         = code
    @raise_errors = options[:raise_errors]
    @timeout      = options[:timeout]
  end

  def self.eval(code, options={})
    new(code, options).eval
  end

  def eval
    temp = build_tempfile
    read, write = IO.pipe
    ChildProcess.build("ruby", temp.path).tap do |process|
      process.io.stdout = write
      process.io.stderr = write
      process.start
      begin
        process.poll_for_exit(@timeout)
      rescue ChildProcess::TimeoutError => e
        process.stop # tries increasingly harsher methods to kill the process.
        return e.message
      end
      write.close
      temp.unlink
    end

    data = read.read
    begin
      # The whole point of this library is to run code in a safe way
      # rubocop:disable Security/MarshalLoad
      Marshal.load(data)
    rescue => e
      if @raise_errors
        raise data
      else
        data
      end
    end
  end

  def self.check(code, expected)
    # The whole point of this library is to run code in a safe way
    # rubocop:disable Security/Eval
    eval(code) == eval(expected)
  end


  private

  def build_tempfile
    file = Tempfile.new('saferuby')
    file.write(MAKE_SAFE_CODE)
    file.write <<-STRING
      result = eval(%q(#{@code}))
      print Marshal.dump(result)
    STRING
    file.rewind
    file
  end
end
