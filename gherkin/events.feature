@grace
Feature: Flagd Provider State Changes

  Background:
    Given a flagd provider is set

  Scenario Outline: Provider events
    When a <event> handler is added
    Then the <event> handler must run
    Examples:
      | event                          |
      | PROVIDER_ERROR                 |
      | PROVIDER_STALE                 |
      | PROVIDER_READY                 |

  Scenario: Provider events chain ready -> stale -> error -> ready
    When a PROVIDER_READY handler is added
    Then the PROVIDER_READY handler must run
    When a PROVIDER_STALE handler is added
    Then the PROVIDER_STALE handler must run
    When a PROVIDER_ERROR handler is added
    Then the PROVIDER_ERROR handler must run
    When a PROVIDER_READY handler is added
    Then the PROVIDER_READY handler must run
