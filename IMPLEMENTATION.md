IMPLEMENTATION
==============

## Debugging

Output debugging messages if `ENV['DEBUG']` is set, for example:

```ruby
puts "Pre Connect request: #{request.inspect}" if ENV["DEBUG"]
```
