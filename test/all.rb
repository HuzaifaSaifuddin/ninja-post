# frozen_string_literal: true

# Runs the whole suite in one process: `bundle exec ruby test/all.rb`.
# Each file below is required (not run individually), so minitest/autorun
# (loaded once, by test_helper) collects every test into a single run.
Dir[File.join(__dir__, "*_test.rb")].sort.each { |f| require f }
