@rpc @in-process
Feature: Flagd Provider State Changes

  Background:
    Given a stable flagd provider

  Scenario Outline: Provider events
    Given a <event> event handler
    When the connection is lost for 6s
    Then the <event> event handler should have been executed
    Examples:
      | event |
      | error |
      | ready |
    @grace
    Examples: Grace Period
      | event |
      | stale |

  @grace
  Scenario: Provider events chain ready -> stale -> error -> ready
    Given a ready event handler
    And a error event handler
    And a stale event handler
    Then the ready event handler should have been executed
    When the connection is lost for 6s
    Then the stale event handler should have been executed
    Then the error event handler should have been executed
    Then the ready event handler should have been executed

  Scenario: Provider events chain ready  -> error -> ready
    Given a ready event handler
    And a error event handler
    Then the ready event handler should have been executed
    When the connection is lost for 6s
    Then the error event handler should have been executed
    Then the ready event handler should have been executed

  Scenario: Flag change event
    Given a String-flag with key "changing-flag" and a default value "false"
    And a change event handler
    When a change event was fired
    And the flag was modified
    Then the flag should be part of the event payload
