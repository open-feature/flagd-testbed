@rpc @in-process @reconnect
Feature: flagd provider disconnect and reconnect functionality

  # This test suite tests the reconnection functionality of flagd providers
  Scenario: Provider reconnection
    Given a stable flagd provider
    And a ready event handler
    And a error event handler
    When a ready event was fired
    Then the ready event handler should have been executed
    When the connection is lost for 6s
    Then the error event handler should have been executed
    Then the ready event handler should have been executed

  Scenario: Provider unavailable
    Given an option "deadlineMs" of type "Integer" with value "1000"
    And a unavailable flagd provider
    And a error event handler
    Then the error event handler should have been executed within 1000ms
