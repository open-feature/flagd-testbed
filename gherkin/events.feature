@rpc @in-process @grace
Feature: Flagd Provider State Changes

  Background:
    Given a unstable flagd provider

  Scenario Outline: Provider events
    Given a <event> event handler
    Then the <event> event handler should have been executed
    Examples:
      | event |
      | error |
      | stale |
      | ready |

  Scenario: Provider events chain ready -> stale -> error -> ready
    Given a ready event handler
    Then the ready event handler should have been executed
    Given a stale event handler
    Then the stale event handler should have been executed
    Given a error event handler
    Then the error event handler should have been executed
    Given a ready event handler
    Then the ready event handler should have been executed
