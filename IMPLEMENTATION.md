IMPLEMENTATION
==============

Document decisions on how we are implementing the specs to be consistent and save time.
Things we MUST do go in SPECS.
Choices between a number of valid possibilities go here. 
Once made, these choices should only be changed after careful consideration.

ASK for clarification of any apparent conflicts with SPECS, GUIDELINES or project instructions.

## Debugging

Output debugging messages if ENV['DEBUG'] is set, for example:

```ruby
puts "Pre Connect request: #{request.inspect}" if ENV["DEBUG"]
```

## Robots.txt Handling

- Used as a "good citizen" mechanism for respecting site preferences
- Graceful fallback (to permitted) if robots.txt is unavailable or invalid
- Match `/^User-agent:\s*ScraperUtils/i` for specific user agent
  - If there is a line matching `/^Disallow:\s*\//` then we are disallowed
  - Check for `/^Crawl-delay:\s*(\d[.0-9]*)/` to extract delay
- If the no crawl-delay is found in that section, then check in the default `/^User-agent:\s*\*/` section
- This is a deliberate significant simplification of the robots.txt specification in RFC 9309.

## Method Organization

- Externalize configuration to improve testability
- Keep shared logic in the main class
- Decisions / information specific to just one class, can be documented there, otherwise it belongs here
