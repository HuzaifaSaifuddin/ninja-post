# frozen_string_literal: true

require "sequel"

# Shared model-layer configuration. Loaded before the model classes.
Sequel::Model.plugin :validation_helpers
Sequel::Model.raise_on_save_failure = false   # actions inspect the result and return 422
