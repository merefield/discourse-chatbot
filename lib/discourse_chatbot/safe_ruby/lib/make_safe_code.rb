MAKE_SAFE_CODE = <<-STRING
def keep_singleton_methods(klass, singleton_methods)
  klass = Object.const_get(klass)
  singleton_methods = singleton_methods.map(&:to_sym)
  undef_methods = (klass.singleton_methods - singleton_methods)

  undef_methods.each do |method|
    klass.singleton_class.send(:undef_method, method)
  end

end

def keep_methods(klass, methods)
  klass = Object.const_get(klass)
  methods = methods.map(&:to_sym)
  undef_methods = (klass.methods(false) - methods)
  undef_methods.each do |method|
    klass.send(:undef_method, method)
  end
end

def clean_constants
  (Object.constants - #{ALLOWED_CONSTANTS}).each do |const|
    Object.send(:remove_const, const) if defined?(const)
  end
end

keep_singleton_methods(:Kernel, #{KERNEL_S_METHODS})
keep_singleton_methods(:Symbol, #{SYMBOL_S_METHODS})
keep_singleton_methods(:String, #{STRING_S_METHODS})
keep_singleton_methods(:IO, #{IO_S_METHODS})

keep_methods(:Kernel, #{KERNEL_METHODS})
keep_methods(:NilClass, #{NILCLASS_METHODS})
keep_methods(:TrueClass, #{TRUECLASS_METHODS})
keep_methods(:FalseClass, #{FALSECLASS_METHODS})
keep_methods(:Enumerable, #{ENUMERABLE_METHODS})
keep_methods(:String, #{STRING_METHODS})
Kernel.class_eval do
 def `(*args)
   raise NoMethodError, "` is unavailable"
 end

 def system(*args)
   raise NoMethodError, "system is unavailable"
 end
end

clean_constants

STRING
