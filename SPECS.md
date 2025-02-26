SPECS
=====

These project specific Specifications go into further details than the
installation and usage notes in `README.md`.

ASK for clarification of any apparent conflicts with IMPLEMENTATION, GUIDELINES or project instructions.

## Core Design Principles

### Error Handling
- Record-level errors abort only that record's processing
- Allow up to 5 + 10% unprocessable records before failing
- External service reliability (e.g., robots.txt) should not block core functionality

### Rate Limiting
- Honor site-specific rate limits when clearly specified
- Apply adaptive delays based on response times
- Use randomized delays to avoid looking like a bot
- Support proxy configuration for geolocation needs

### Testing
- Ensure components are independently testable
- Avoid timing-based tests in favor of logic validation
- Keep test scenarios focused and under 20 lines
