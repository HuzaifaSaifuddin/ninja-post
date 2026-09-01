# frozen_string_literal: true
# Run: bundle exec ruby scratch/06_module_function.rb
#
# =============================================================================
# `module_function` — what it does and why config/database.rb uses it
# =============================================================================
# Problem it solves: you want a bag of stateless helper methods that you can
# call as `MyModule.helper` (no instance needed), like Ruby's `Math.sqrt`.
#
# `module_function` does TWO things to the methods defined after it:
#   1. makes a COPY of each as a private module-level ("class") method
#      -> callable as `MyModule.name`
#   2. makes the ORIGINAL instance-method version PRIVATE
#      -> only usable via `include` and only internally
# =============================================================================

def section(t) = puts("\n=== #{t} ===")

# -----------------------------------------------------------------------------
# 1. Plain module: instance methods only. Cannot call them on the module.
# -----------------------------------------------------------------------------
module Plain
  def greet = "hi from Plain"
end

section "Plain module"
begin
  Plain.greet
rescue NoMethodError => e
  puts "Plain.greet -> NoMethodError: #{e.message}"
end
# you'd have to do: Object.new.extend(Plain).greet   — clunky

# -----------------------------------------------------------------------------
# 2. `module_function` with no args: applies to everything defined AFTER it.
# -----------------------------------------------------------------------------
module Tools
  module_function

  def double(x) = x * 2
  def shout(s)  = "#{s.upcase}!"
end

section "module_function (bare)"
puts "Tools.double(21)   -> #{Tools.double(21)}"
puts "Tools.shout('yo')  -> #{Tools.shout('yo')}"

# The instance-method copies are PRIVATE:
puts "Tools.private_instance_methods -> #{Tools.private_instance_methods(false).inspect}"
begin
  Class.new { include Tools }.new.double(2)
rescue NoMethodError => e
  puts "included then called publicly -> NoMethodError (it's private): #{e.message}"
end

# ...but usable internally by a class that includes the module:
class Calc
  include Tools
  def run = double(10) + double(5)   # calls the private instance-method versions
end
puts "Calc.new.run       -> #{Calc.new.run}"

# -----------------------------------------------------------------------------
# 3. `module_function :name` with args: applies only to those named methods.
#    Methods NOT listed stay as normal public instance methods.
# -----------------------------------------------------------------------------
module Mixed
  def helper       = "callable as Mixed.helper"
  def internal_only = "not on the module"
  module_function :helper
end

section "module_function :helper (targeted)"
puts "Mixed.helper           -> #{Mixed.helper}"
begin
  Mixed.internal_only
rescue NoMethodError => e
  puts "Mixed.internal_only    -> NoMethodError: #{e.message}"
end

# -----------------------------------------------------------------------------
# 4. The copies are independent — proof that it's a copy, not an alias.
# -----------------------------------------------------------------------------
module Independent
  module_function

  def name = "original"
end

Independent.define_singleton_method(:name) { "redefined singleton" }

section "copy, not alias"
puts "Independent.name -> #{Independent.name}"   # redefined singleton
klass = Class.new { include Independent; public :name }
puts "included .name   -> #{klass.new.name}"     # still 'original'

# -----------------------------------------------------------------------------
# 5. How it compares to the alternatives
# -----------------------------------------------------------------------------
section "alternatives to the same goal"

module ViaSelf            # `def self.x` — most common, explicit
  def self.a = "self.a"
end

module ViaExtendSelf      # `extend self` — all methods become BOTH public
  extend self             # instance methods AND module methods (not private)
  def b = "b"
end

puts "ViaSelf.a          -> #{ViaSelf.a}"
puts "ViaExtendSelf.b    -> #{ViaExtendSelf.b}"
puts "ViaExtendSelf instance method still public? " \
     "#{ViaExtendSelf.public_instance_methods(false).inspect}"

puts <<~SUMMARY

  ---------------------------------------------------------------------------
  def self.foo       : one method at a time, explicit, no instance version
  extend self        : module methods + PUBLIC instance methods (mixin stays usable)
  module_function    : module methods + PRIVATE instance versions
                       -> "call it on the module; if you mix me in, it's internal"
  ---------------------------------------------------------------------------

  config/database.rb uses `module_function` because connect! / url / admin_url
  are stateless utilities meant to be called as NinjaPost::Database.connect!.
  We never mix the module into anything, so `def self.` would work equally —
  `module_function` is just the idiom for "namespace of module-level helpers".
SUMMARY
