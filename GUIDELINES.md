# Project-Specific Guidelines

## Error Handling Approaches

Process each authority's site in issolation - problems with one authority are irrelevant to others.

* we do a 2nd attempt of authorities with the same proxy settings
* and a 3rd attemopt for those that failed with the proxy but with the proxy disabled

Within a proxy distinguish between

* Errors that are specific to that record
    * only allow 5 such errors plus 10% of successfully processed records
    * these could be regarded as not worth retrying (we currently do)
* Any other exceptions stop the processing of that authorities site

### Fail Fast on deeper calls

- Raise exceptions early (when they are clearly detectable)
- input validation according to scraper specs

### Be forgiving on things that don't matter

- not all sites have robots.txt, and not all robots.txt are well formatted therefor stop processing the file on obvious conflicts with the specs,
but if the file is bad, just treat it as missing.

- don't fuss over things we are not going to record.

- we do detect maintenance pages because that is a helpful and simple clue that we wont find the data, and we can just wait till the site is back online

## Type Checking

### Partial Duck Typing
- Focus on behavior over types internally (.robocop.yml should disable requiring everything to be typed)
- Runtime validation of values
- document public API though
  - Use @params and @returns comments to document types for external uses of the public methods (rubymine will use thesefor checking)

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
- Log only key events (key means down to adding a record)
- Focus on errors

