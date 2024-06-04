# frozen_string_literal: true

ALLOWED_CONSTANTS= [
  :Object, :Module, :Class, :BasicObject, :Kernel, :NilClass, :NIL, :Data, :TrueClass, :TRUE, :FalseClass, :FALSE, :Encoding, 
  :Comparable, :Enumerable, :String, :Symbol, :Exception, :SystemExit, :SignalException, :Interrupt, :StandardError, :TypeError,
  :ArgumentError, :IndexError, :KeyError, :RangeError, :ScriptError, :SyntaxError, :LoadError, :NotImplementedError, :NameError,
  :NoMethodError, :RuntimeError, :SecurityError, :NoMemoryError, :EncodingError, :SystemCallError, :Errno, :ZeroDivisionError,
  :FloatDomainError, :Numeric, :Integer, :Fixnum, :Float, :Bignum, :Array, :Hash,  :Struct, :RegexpError, :Regexp,
  :MatchData, :Marshal, :Range, :IOError, :EOFError, :IO, :STDIN, :STDOUT, :STDERR, :Time, :Random,
  :Signal, :Proc, :LocalJumpError, :SystemStackError, :Method, :UnboundMethod, :Binding, :Math, :Enumerator,
  :StopIteration, :RubyVM, :Thread, :TOPLEVEL_BINDING, :ThreadGroup, :Mutex, :ThreadError, :Fiber, :FiberError, :Rational, :Complex,
  :RUBY_VERSION, :RUBY_RELEASE_DATE, :RUBY_PLATFORM, :RUBY_PATCHLEVEL, :RUBY_REVISION, :RUBY_DESCRIPTION, :RUBY_COPYRIGHT, :RUBY_ENGINE,
  :TracePoint, :ARGV, :Gem, :RbConfig, :Config, :CROSS_COMPILING, :Date, :ConditionVariable, :Queue, :SizedQueue, :MonitorMixin, :Monitor,
  :Exception2MessageMapper, :IRB, :RubyToken, :RubyLex, :Readline, :RUBYGEMS_ACTIVATION_MONITOR
]
