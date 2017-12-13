require 'crossriverbank/version' unless defined? CrossRiverBank::VERSION
require 'finix'
# require 'finix/client'
# require 'finix/errors'

module CrossRiverBank
  Finix.singleton_methods.each do |m|
    (class << self; self; end).send :define_method, m, Finix.method(m).to_proc
  end

  classes = Finix.constants.find_all {|m| (Finix.const_get m).kind_of? Class}
  classes.each do |cls|
    clz = Class.new Finix.const_get cls
    self.const_set(cls, clz)
  end

  [CrossRiverBank.errors_registry, CrossRiverBank.hypermedia_registry].each do |registry|
    registry.each do |key, value|
      registry[key] = CrossRiverBank.const_get value.name.split('::').last
    end
  end
end
