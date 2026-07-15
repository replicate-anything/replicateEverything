# Sanitize free-text Shiny feedback input

Strips HTML tags and control characters; trims and caps length. Returns
plain text only (never evaluated or rendered as HTML).

## Usage

``` r
sanitize_shiny_feedback_text(text, max_chars = 2000L)
```

## Arguments

- text:

  Character scalar.

- max_chars:

  Maximum length after sanitization.

## Value

Sanitized character scalar.
