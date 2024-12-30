@rpc @caching
Feature: Flag evaluation with Caching

# This test suite contains scenarios to test the flag evaluation API with caching (RPC only)
  Background:
    Given an option "cache" of type "CacheType" with value "lru"
    And a stable flagd provider

  Scenario Outline: Resolves <type> details with caching
    Given a <type>-flag with key "<key>" and a default value "<default>"
    When the flag was evaluated with details
    Then the resolved details value should be "<resolved_value>"
    And the variant should be "<resolved_variant>"
    And the reason should be "STATIC"
    When the flag was evaluated with details
    Then the resolved details value should be "<resolved_value>"
    And the variant should be "<resolved_variant>"
    And the reason should be "CACHED"

    Examples:
      | key          | type    | default | resolved_variant | resolved_value                                                                |
      | boolean-flag | Boolean | false   | on               | true                                                                          |
      | string-flag  | String  | bye     | greeting         | hi                                                                            |
      | integer-flag | Integer | 1       | ten              | 10                                                                            |
      | float-flag   | Float   | 0.1     | half             | 0.5                                                                           |
      | object-flag  | Object  | null    | template         | {"showImages": true, "title": "Check out these pics!", "imagesPerPage": 100 } |

  Scenario: Flag change event with caching
    Given a String-flag with key "changing-flag" and a default value "false"
    And a change event handler
    When a change event was fired
    And the flag was modified
    And the flag was evaluated with details
    Then the reason should be "STATIC"
    When the flag was evaluated with details
    Then the reason should be "CACHED"
    When a change event was fired
    And the flag was modified
    And the flag was evaluated with details
    Then the reason should be "STATIC"
    When the flag was evaluated with details
    Then the reason should be "CACHED"

  Scenario: Stale and Error stage
    Given a ready event handler
    And a stale event handler
    And a error event handler
    And a String-flag with key "changing-flag" and a default value "false"
    When the flag was evaluated with details
    Then the reason should be "STATIC"
    When the flag was evaluated with details
    Then the reason should be "CACHED"
    When the connection is lost for 6s
    And a stale event was fired
    And the flag was evaluated with details
    Then the reason should be "CACHED"
    When a error event was fired
    And a ready event was fired
    And the flag was evaluated with details
    Then the reason should be "STATIC"
