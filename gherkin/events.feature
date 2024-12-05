@rpc @in-process @grace
Feature: Flagd Provider State Changes

  Background:
    Given a unstable flagd provider

  Scenario Outline: Provider events
    Given a <event> event handler
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
    When a ready event was fired
    Then the ready event handler should have been executed
    When a stale event was fired
    Then the stale event handler should have been executed
    When a error event was fired
    Then the error event handler should have been executed
    When a ready event was fired
    Then the ready event handler should have been executed
