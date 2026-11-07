# Git clean filters for public runtime policy. Uses macOS system Ruby and Psych.
require 'psych'

# Registry-scoped npm keys end in :_authToken, :username, etc.
def authentication_key?(key)
  name = key.to_s.split(':').last.to_s.delete("\"'").downcase.gsub(/[^a-z0-9]/, '')
  name.include?('auth') || name.include?('token') ||
    name.end_with?('password', 'username') || %w[
      email otp cert certfile key keyfile clientcert clientkey privatekey
    ].include?(name)
end

def public_url(value)
  value.gsub(%r{(https?://)[^/\s@]+@}i, '\1')
end

# Work on syntax nodes, not Ruby objects, so YAML tags cannot instantiate objects.
def scrub_yaml(node)
  case node
  when Psych::Nodes::Alias
    raise 'YAML aliases are not supported in public runtime policy'
  when Psych::Nodes::Mapping
    node.children.replace(node.children.each_slice(2).reject do |key, _value|
      raise 'Non-scalar YAML keys are not supported' unless key.is_a?(Psych::Nodes::Scalar)
      authentication_key?(key.value)
    end.flatten(1))
  end

  if node.is_a?(Psych::Nodes::Scalar)
    node.value = public_url(node.value)
  elsif node.children
    node.children.each { |child| scrub_yaml(child) }
  end
end

begin
  input = STDIN.read
  case ARGV.fetch(0)
  when 'yaml'
    stream = Psych.parse_stream(input)
    raise 'Expected one YAML mapping' unless stream.children.length == 1 &&
      stream.children.first.root.is_a?(Psych::Nodes::Mapping)
    scrub_yaml(stream)
    output = stream.to_yaml
  when 'npmrc'
    output = input.lines.reject do |line|
      next false if line.strip.empty? || line.lstrip.start_with?('#', ';')
      match = line.match(/\A\s*([^=]+?)\s*=(.*)\z/m)
      raise 'Expected an npmrc assignment' unless match
      authentication_key?(match[1])
    end.map { |line| public_url(line) }.join
  else
    raise 'Unknown runtime policy format'
  end
  # Buffer everything: a parse failure must never emit a partial credential file.
  STDOUT.write(output)
rescue StandardError
  # Parser exceptions can contain source values. Never print their messages.
  warn 'Runtime policy filter failed; refusing to stage unfiltered content'
  exit 1
end
