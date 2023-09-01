Feature: flagd providers

  # This test suite contains scenarios to test flagd providers (both RPC and in-process).
  # It's associated with the flags configured in flags/custom-ops.json and flags/zero-flags.json
  # It should be used in conjunection with the suites supplied by the OpenFeature specification

  Background:
    Given a flagd provider is set

  # events
  Scenario: Provider ready event
    When a PROVIDER_READY handler is added
    Then the PROVIDER_READY handler must run

  Scenario: Flag change event
    When a PROVIDER_CONFIGURATION_CHANGED handler is added
    And a flag with key "changing-flag" is modified
    Then the PROVIDER_CONFIGURATION_CHANGED handler must run
    And the event details must indicate "changing-flag" was altered

  # zero evaluation
  Scenario: Resolves boolean zero value
    When a boolean flag with key "boolean-zero-flag" is evaluated with default value "true"
    Then the resolved boolean value should be "false"

  Scenario: Resolves string zero value
    When a string flag with key "string-zero-flag" is evaluated with default value "hi"
    Then the resolved string value should be ""

  Scenario: Resolves integer zero value
    When an integer flag with key "integer-zero-flag" is evaluated with default value 1
    Then the resolved integer value should be 0

  Scenario: Resolves float zero value
    When a float flag with key "float-zero-flag" is evaluated with default value 0.1
    Then the resolved float value should be 0.0

  # custom operators
  Scenario Outline: Fractional operator
    When a string flag with key "fractional-flag" is evaluated with default value "fallback"
    And a context containing a nested property with outer key "user" and inner key "name", with value <name>
    Then the returned value should be <value>
    Examples:
      | name  | value    |
      | jack  | clubs    |
      | queen | diamonds |
      | ace   | hearts   |
      | joker | spades   |

  Scenario Outline: Substring operators
    When a string flag with key "starts-ends-flag" is evaluated with default value "fallback"
    And a context containing a key "id", with value <id>
    Then the returned value should be <value>
    Examples:
      | id     | value   |
      | abcdef | prefix  |
      | uvwxyz | postfix |
      | abcxyz | prefix  |
      | lmnopq | nomatch |

  Scenario Outline: Semantic version operator numeric comparision
    When a string flag with key "equal-greater-lesser-version-flag" is evaluated with default value "fallback"
    And a context containing a key "version", with value <version>
    Then the returned value should be <value>
    Examples:
      | version     | value   |
      | 2.0.0       | equal   |
      | 2.1.0       | greater |
      | 1.9.0       | lesser  |
      | 2.0.0-alpha | lesser  |
      | 2.0.0.0     | invalid |

  Scenario Outline: Semantic version operator semantic comparision
    When a string flag with key "major-minor-version-flag" is evaluated with default value "fallback"
    And a context containing a key "version", with value <version>
    Then the returned value should be <value>
    Examples:
      | version | value |
      | 3.0.1   | minor |
      | 3.1.0   | major |
      | 4.0.0   | none  |
