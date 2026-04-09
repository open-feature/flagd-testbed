@string
Feature: Evaluator string comparison operator

  # Tests the starts_with and ends_with custom operators.

  Scenario Outline: Substring operators
    Given an evaluator
    And a String-flag with key "starts-ends-flag" and a fallback value "fallback"
    And a context containing a key "id", with type "String" and with value "<id>"
    When the flag was evaluated with details
    Then the resolved details value should be "<value>"

    Examples:
      | id     | value   |
      | abcdef | prefix  |
      | uvwxyz | postfix |
      | abcxyz | prefix  |
      | lmnopq | none    |

  # Follow-up error scenarios from https://github.com/open-feature/flagd/issues/1874
  # starts_with and ends_with must return null (not false) on error so that the
  # default variant is selected, rather than looking up a non-existent "false" variant.

  @operator-errors
  Scenario Outline: starts_with and ends_with return null for non-string input
    Given an evaluator
    And a String-flag with key "<key>" and a fallback value "wrong"
    And a context containing a key "num", with type "Integer" and with value "123"
    When the flag was evaluated with details
    Then the resolved details value should be "fallback"
    And the reason should be "DEFAULT"
    Examples:
      | key                         |
      | starts-with-non-string-flag |
      | ends-with-non-string-flag   |

  @operator-errors
  Scenario Outline: starts_with and ends_with return null for wrong argument count
    Given an evaluator
    And a String-flag with key "<key>" and a fallback value "wrong"
    When the flag was evaluated with details
    Then the resolved details value should be "fallback"
    And the reason should be "DEFAULT"
    Examples:
      | key                         |
      | starts-with-wrong-args-flag |
      | ends-with-wrong-args-flag   |
