@rpc @in-process @file
Feature: flagd provider disconnect and reconnect functionality

  Scenario Outline: Connection
    Given a <name> flagd provider
    And a Boolean-flag with key "boolean-flag" and a default value "true"
    When the flag was evaluated with details
    Then the resolved details value should be "true"

    Scenarios: Stable
      | name   |
      | stable |
    @targetURI
    Scenarios: Target URI
      | name   |
      | target |
    @customCert
    Scenarios: Certificates
      | name |
      | ssl  |
    @unixsocket @os.linux
    Scenarios: Unixsocket
      | name   |
      | socket |

  @reconnect
  # This test suite tests the reconnection functionality of flagd providers
  Scenario Outline: Provider reconnection
    Given a <name> flagd provider
    And a ready event handler
    And a error event handler
    When a ready event was fired
    When the connection is lost for 3s
    Then the error event handler should have been executed
    Then the ready event handler should have been executed

    Scenarios: Stable
      | name   |
      | stable |
    @targetURI
    Scenarios: Target URI
      | name   |
      | socket |
    @customCert
    Scenarios: Certificates
      | name |
      | ssl  |
    # unix sockets and reconnects is a strange topic and not as easily handled as like tcp reconnects
    #    @unixsocket @os.linux
    #    Scenarios: Unixsocket
    #      | name   |
    #      | socket |

  @unavailable
  Scenario: Provider unavailable
    Given an option "deadlineMs" of type "Integer" with value "1000"
    And a unavailable flagd provider
    And a error event handler
    Then the error event handler should have been executed within 3000ms
