Feature: flagd provider reconnect functionality

  # This test suite tests the reconnection functionality of flagd providers
  
  Scenario: Provider reconnection
    Given a flagd provider is set
    When a PROVIDER_READY handler and a PROVIDER_ERROR handler are added
    Then the PROVIDER_READY handler must run when the provider connects
    And the PROVIDER_ERROR handler must run when the provider's connection is lost
    And when the connection is reestablished the PROVIDER_READY handler must run again
