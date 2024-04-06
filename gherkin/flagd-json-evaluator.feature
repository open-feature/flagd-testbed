Feature: flagd json evaluation

  # This test suite contains scenarios to test the json-evaluation of flagd and flag-in-process providers.
  # It's associated with the flags configured in flags/changing-flag.json, flags/zero-flags.json, flags/custom-ops.json and evaluator-refs.json.
  # It should be used in conjunction with the suites supplied by the OpenFeature specification.

  Background:
    Given a flagd provider is set

  # evaluator refs
  Scenario Outline: Evaluator reuse
    When a string flag with key <key> is evaluated with default value "fallback"
    And a context containing a key "email", with value "ballmer@macrosoft.com"
    Then the returned value should be <value>
    Examples:
      | key                              | value |
      | "some-email-targeted-flag"       | "hi"  |
      | "some-other-email-targeted-flag" | "yes" |

  # custom operators
  Scenario Outline: Fractional operator
    When a string flag with key "fractional-flag" is evaluated with default value "fallback"
    And a context containing a nested property with outer key "user" and inner key "name", with value <name>
    Then the returned value should be <value>
    Examples:
      | name    | value      |
      | "jack"  | "spades"   |
      | "queen" | "clubs"    |
      | "ten"   | "diamonds" |
      | "nine"  | "hearts"   |
      | 3       | "diamonds" |

  Scenario Outline: Fractional operator with shared seed
    When a string flag with key "fractional-flag-A-shared-seed" is evaluated with default value "fallback"
    And a context containing a nested property with outer key "user" and inner key "name", with value <name>
    Then the returned value should be <value>
    Examples:
      | name    | value      |
      | "jack"  | "hearts"   |
      | "queen" | "spades"   |
      | "ten"   | "hearts"   |
      | "nine"  | "diamonds" |

  Scenario Outline: Second fractional operator with shared seed
    When a string flag with key "fractional-flag-B-shared-seed" is evaluated with default value "fallback"
    And a context containing a nested property with outer key "user" and inner key "name", with value <name>
    Then the returned value should be <value>
    Examples:
      | name    | value |
      | "jack"  | "ace-of-hearts"   |
      | "queen" | "ace-of-spades"   |
      | "ten"   | "ace-of-hearts"   |
      | "nine"  | "ace-of-diamonds" |

  Scenario Outline: Substring operators
    When a string flag with key "starts-ends-flag" is evaluated with default value "fallback"
    And a context containing a key "id", with value <id>
    Then the returned value should be <value>
    Examples:
      | id       | value     |
      | "abcdef" | "prefix"  |
      | "uvwxyz" | "postfix" |
      | "abcxyz" | "prefix"  |
      | "lmnopq" | "none"    |
      | 3        | "none"    |

  Scenario Outline: Semantic version operator numeric comparison
    When a string flag with key "equal-greater-lesser-version-flag" is evaluated with default value "fallback"
    And a context containing a key "version", with value <version>
    Then the returned value should be <value>
    Examples:
      | version       | value     |
      | "2.0.0"       | "equal"   |
      | "2.1.0"       | "greater" |
      | "1.9.0"       | "lesser"  |
      | "2.0.0-alpha" | "lesser"  |
      | "2.0.0.0"     | "none"    |

  Scenario Outline: Semantic version operator semantic comparison
    When a string flag with key "major-minor-version-flag" is evaluated with default value "fallback"
    And a context containing a key "version", with value <version>
    Then the returned value should be <value>
    Examples:
      | version | value   |
      | "3.0.1" | "minor" |
      | "3.1.0" | "major" |
      | "4.0.0" | "none"  |

  Scenario Outline: Time-based operations
    When an integer flag with key "timestamp-flag" is evaluated with default value 0
    And a context containing a key "time", with value <time>
    Then the returned value should be <value>
    Examples:
      | time       | value |
      | 1          | -1    |
      | 4133980802 | 1     |

  Scenario Outline: Targeting by targeting key
    When a string flag with key "targeting-key-flag" is evaluated with default value "fallback"
    And a context containing a targeting key with value <targeting key>
    Then the returned value should be <value>
    Then the returned reason should be <reason>
    Examples:
      | targeting key                          | value  | reason            |
      | "5c3d8535-f81a-4478-a6d3-afaa4d51199e" | "hit"  | "TARGETING_MATCH" |
      | "f20bd32d-703b-48b6-bc8e-79d53c85134a" | "miss" | "DEFAULT"         |

  Scenario Outline: Errors and edge cases
    When an integer flag with key <key> is evaluated with default value 3
    Then the returned value should be <value>
    Examples:
      | key                                 | value |
      | "targeting-null-variant-flag"       | 2     |
      | "error-targeting-flag"              | 3     |
      | "missing-variant-targeting-flag"    | 3     |
      | "non-string-variant-targeting-flag" | 2     |
      | "empty-targeting-flag"              | 1     |
