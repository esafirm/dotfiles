# frozen_string_literal: true

# Array extension function for parsing to hash
class Array
  def standard_params(filter = /^((?!\:).)*$/)
    grep(filter)
  end

  # Allow array contains : or = to be parsed
  def parse_named_params(filter = /:|\=/, downcase: false)
    grep(filter).parse_to_hash(filter, downcase: downcase)
  end

  # Parse key:value or key=value as hash[:key] = value
  def parse_to_hash(delimiter = /[\=,:]/, downcase: false)
    each_with_object({}) do |line, params|
      key, val = line.chomp.split(delimiter, 2)
      params[:"#{downcase ? key.downcase : key}"] = val
    end
  end
end
