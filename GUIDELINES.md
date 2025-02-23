# Project-Specific Guidelines

## Error Handling Approaches

### Fail Fast
- Abort on first fatal error WITHIN authority. errors with specific record just aborts that record (but we dont allow more than 5 + 10% of these errors)
- Raise exceptions early
- input validation according to scraper specs

## Type Checking

### Duck Typing
- Focus on behavior over types
- Runtime validation
- document public API though

## Input Validation

### Early Validation
- Check all inputs at system boundaries
- Fail on any invalid input

## Testing Strategies

### Behavior-Driven Development (BDD)
- Focus on behavior specifications
- User-centric scenarios
- Best for: User-facing features

## Documentation Approaches

### Just-Enough Documentation
- Focus on key decisions
- Document non-obvious choices
- Best for: Rapid development, internal tools

## Logging Philosophy

### Minimal Logging
- Log only key events (down to adding a record)
- Focus on errors

