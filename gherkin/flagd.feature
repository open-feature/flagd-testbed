Feature: flagd providers

  # This test suite contains scenarios to test flagd providers.
  # It's associated with the flags configured in flags/changing-flag.json and flags/zero-flags.json.
  # It should be used in conjunction with the suites supplied by the OpenFeature specification.

  Background:
    Given an option "cache" of type "CacheType" with value "disabled"
    And a stable flagd provider

  # events
  Scenario: Provider ready event
    Given a ready event handler
    Then the ready event handler should have been executed

  Scenario: Flag change event
    Given a String-flag with key "changing-flag" and a default value "false"
    And a change event handler
    When a change event was fired
    Then the change event handler should have been executed
    And the flag was modified

  Scenario Outline: Resolves zero value
    Given a <type>-flag with key "<key>" and a default value "<default>"
    When the flag was evaluated with details
    Then the resolved details value should be "<resolved_value>"

    Examples:
      | key               | type    | default | resolved_value |
      | boolean-zero-flag | Boolean | true    | false          |
      | string-zero-flag  | String  | hi      |                |
      | integer-zero-flag | Integer | 1       | 0              |
      | float-zero-flag   | Float   | 0.1     | 0.0            |
