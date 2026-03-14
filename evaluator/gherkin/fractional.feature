@fractional
Feature: Evaluator fractional operator

  # Tests the fractional bucketing operator for consistent user assignment.

  Background:
    Given an evaluator

  Scenario Outline: Fractional operator
    Given a String-flag with key "fractional-flag" and a fallback value "fallback"
    And a context containing a nested property with outer key "user" and inner key "name", with value "<name>"
    When the flag was evaluated with details
    Then the resolved details value should be "<value>"

    Examples:
      | name  | value    |
      | jack  | spades   |
      | queen | clubs    |
      | ten   | diamonds |
      | nine  | hearts   |
      | 3     | diamonds |

  Scenario Outline: Fractional operator shorthand
    Given a String-flag with key "fractional-flag-shorthand" and a fallback value "fallback"
    And a context containing a targeting key with value "<targeting_key>"
    When the flag was evaluated with details
    Then the resolved details value should be "<value>"

    Examples:
      | targeting_key    | value |
      | jon@company.com  | heads |
      | jane@company.com | tails |

  Scenario Outline: Fractional operator with shared seed
    Given a String-flag with key "fractional-flag-A-shared-seed" and a fallback value "fallback"
    And a context containing a nested property with outer key "user" and inner key "name", with value "<name>"
    When the flag was evaluated with details
    Then the resolved details value should be "<value>"

    Examples:
      | name  | value    |
      | jack  | hearts   |
      | queen | spades   |
      | ten   | hearts   |
      | nine  | diamonds |

  Scenario Outline: Second fractional operator with shared seed
    Given a String-flag with key "fractional-flag-B-shared-seed" and a fallback value "fallback"
    And a context containing a nested property with outer key "user" and inner key "name", with value "<name>"
    When the flag was evaluated with details
    Then the resolved details value should be "<value>"

    Examples:
      | name  | value           |
      | jack  | ace-of-hearts   |
      | queen | ace-of-spades   |
      | ten   | ace-of-hearts   |
      | nine  | ace-of-diamonds |
