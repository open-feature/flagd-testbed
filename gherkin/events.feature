@rpc @in-process @grace
Feature: Flagd Provider State Changes

  Background:
    Given a stable flagd provider

  Scenario Outline: Provider events
    Given a <event> event handler
    When the connection is lost for 6s
    Then the <event> event handler should have been executed
    Examples:
      | event |
      | stale |
      | error |
      | ready |

  Scenario: Provider events chain ready -> stale -> error -> ready
    Given a ready event handler
    And a error event handler
    And a stale event handler
    Then the ready event handler should have been executed
    When the connection is lost for 6s
    Then the stale event handler should have been executed
    Then the error event handler should have been executed
    Then the ready event handler should have been executed
