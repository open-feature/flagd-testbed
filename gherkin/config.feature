Feature: Configuration Test
"""markdown
  This is the official option configuration table
  | Option name           | Environment variable name      | Explanation                                                                     | Type & Values                | Default                       | Compatible resolver |
  | --------------------- | ------------------------------ | ------------------------------------------------------------------------------- | ---------------------------- | ----------------------------- | ------------------- |
  | resolver              | FLAGD_RESOLVER                 | mode of operation                                                               | String - `rpc`, `in-process` | rpc                           | rpc & in-process    |
  | host                  | FLAGD_HOST                     | remote host                                                                     | String                       | localhost                     | rpc & in-process    |
  | port                  | FLAGD_PORT                     | remote port                                                                     | int                          | 8013 (rpc), 8015 (in-process) | rpc & in-process    |
  | targetUri             | FLAGD_TARGET_URI               | alternative to host/port, supporting custom name resolution                     | string                       | null                          | rpc & in-process    |
  | tls                   | FLAGD_TLS                      | connection encryption                                                           | boolean                      | false                         | rpc & in-process    |
  | socketPath            | FLAGD_SOCKET_PATH              | alternative to host port, unix socket                                           | String                       | null                          | rpc & in-process    |
  | certPath              | FLAGD_SERVER_CERT_PATH         | tls cert path                                                                   | String                       | null                          | rpc & in-process    |
  | deadlineMs            | FLAGD_DEADLINE_MS              | deadline for unary calls, and timeout for initialization                        | int                          | 500                           | rpc & in-process    |
  | streamDeadlineMs      | FLAGD_STREAM_DEADLINE_MS       | deadline for streaming calls, useful as an application-layer keepalive          | int                          | 600000                        | rpc & in-process    |
  | retryBackoffMs        | FLAGD_RETRY_BACKOFF_MS         | initial backoff for stream retry                                                | int                          | 1000                          | rpc & in-process    |
  | retryBackoffMaxMs     | FLAGD_RETRY_BACKOFF_MAX_MS     | maximum backoff for stream retry                                                | int                          | 120000                        | rpc & in-process    |
  | retryGracePeriod      | FLAGD_RETRY_GRACE_PERIOD       | time before provider moves from STALE to ERROR state                            | int                          | 5                             | rpc & in-process    |
  | keepAliveTime         | FLAGD_KEEP_ALIVE_TIME_MS       | http 2 keepalive                                                                | long                         | 0                             | rpc & in-process    |
  | cache                 | FLAGD_CACHE                    | enable cache of static flags                                                    | String - `lru`, `disabled`   | lru                           | rpc                 |
  | maxCacheSize          | FLAGD_MAX_CACHE_SIZE           | max size of static flag cache                                                   | int                          | 1000                          | rpc                 |
  | selector              | FLAGD_SOURCE_SELECTOR          | selects a single sync source to retrieve flags from only that source            | string                       | null                          | in-process          |
  | offlineFlagSourcePath | FLAGD_OFFLINE_FLAG_SOURCE_PATH | offline, file-based flag definitions, overrides host/port/targetUri             | string                       | null                          | in-process          |
  | offlinePollIntervalMs | FLAGD_OFFLINE_POLL_MS          | poll interval for reading offlineFlagSourcePath                                 | int                          | 5000                          | in-process          |
  | contextEnricher       | -                              | sync-metadata to evaluation context mapping function                            | function                     | identity function             | in-process          |
  """

  @rpc @in-process
  Scenario Outline: Default Config
    When a config was initialized
    Then the option "<option>" of type "<type>" should have the value "<default>"
    Scenarios: Basic
      | option     | type         | default   |
      | resolver   | ResolverType | rpc       |
      | host       | String       | localhost |
      | port       | Integer      | 8013      |
      | tls        | Boolean      | false     |
      | deadlineMs | Integer      | 500       |
    @targetURI
    Scenarios: Target URI
      | option    | type   | default |
      | targetUri | String | null    |
    @customCert
    Scenarios: Certificates
      | option   | type   | default |
      | certPath | String | null    |
    @unixsocket
    Scenarios: Unixsocket
      | option     | type   | default |
      | socketPath | String | null    |
    @events
    Scenarios: Events
      | option            | type    | default |
      | streamDeadlineMs  | Integer | 600000  |
      | keepAliveTime     | Long    | 0       |
      | retryBackoffMs    | Integer | 1000    |
      | retryBackoffMaxMs | Integer | 120000  |
      | retryGracePeriod  | Integer | 5       |
    @sync
    Scenarios: Sync
      | option            | type    | default |
      | streamDeadlineMs  | Integer | 600000  |
      | keepAliveTime     | Long    | 0       |
      | retryBackoffMs    | Integer | 1000    |
      | retryBackoffMaxMs | Integer | 120000  |
      | retryGracePeriod  | Integer | 5       |
      | selector          | String  | null    |
    @caching
    Scenarios: caching
      | option       | type      | default |
      | cache        | CacheType | lru     |
      | maxCacheSize | Integer   | 1000    |
    @offline
    Scenarios: offline
      | option                | type    | default |
      | offlineFlagSourcePath | String  | null    |
      | offlinePollIntervalMs | Integer | 5000    |

  @rpc
  Scenario Outline: Default Config RPC
    Given an option "resolver" of type "ResolverType" with value "rpc"
    When a config was initialized
    Then the option "<option>" of type "<type>" should have the value "<default>"
    Scenarios:
      | option | type    | default |
      | port   | Integer | 8013    |

  @in-process
  Scenario Outline: Default Config In-Process
    Given an option "resolver" of type "ResolverType" with value "in-process"
    When a config was initialized
    Then the option "<option>" of type "<type>" should have the value "<default>"
    Scenarios:
      | option | type    | default |
      | port   | Integer | 8015    |

  @rpc @in-process
  Scenario Outline: Dedicated Config
    Given an option "<option>" of type "<type>" with value "<value>"
    When a config was initialized
    Then the option "<option>" of type "<type>" should have the value "<value>"
    Scenarios:
      | option     | type         | value      |
      | resolver   | ResolverType | in-process |
      | host       | String       | local      |
      | tls        | Boolean      | True       |
      | port       | Integer      | 1234       |
      | deadlineMs | Integer      | 123        |
    @targetURI
    Scenarios: Target URI
      | option    | type   | value |
      | targetUri | String | path  |
    @customCert
    Scenarios: Custom Certificate
      | option   | type   | value |
      | certPath | String | path  |
    @unixsocket
    Scenarios: Unixsocket
      | option     | type   | value |
      | socketPath | String | path  |
    @events
    Scenarios: events
      | option            | type    | value  |
      | streamDeadlineMs  | Integer | 500000 |
      | keepAliveTime     | Long    | 5      |
      | retryBackoffMs    | Integer | 5000   |
      | retryBackoffMaxMs | Integer | 12000  |
      | retryGracePeriod  | Integer | 10     |
    @sync
    Scenarios: sync
      | option            | type    | value    |
      | streamDeadlineMs  | Integer | 500000   |
      | keepAliveTime     | Long    | 5        |
      | retryBackoffMs    | Integer | 5000     |
      | retryBackoffMaxMs | Integer | 12000    |
      | retryGracePeriod  | Integer | 10       |
      | selector          | String  | selector |
    @caching
    Scenarios: caching
      | option       | type      | value    |
      | cache        | CacheType | disabled |
      | maxCacheSize | Integer   | 1236     |
    @offline
    Scenarios: offline
      | option                | type    | value |
      | offlineFlagSourcePath | String  | path  |
      | offlinePollIntervalMs | Integer | 1000  |

  @rpc @in-process
  Scenario Outline: Dedicated Config via Env_var
    Given an environment variable "<env>" with value "<value>"
    When a config was initialized
    Then the option "<option>" of type "<type>" should have the value "<value>"
    Scenarios:
      | option     | env               | type         | value      |
      | resolver   | FLAGD_RESOLVER    | ResolverType | in-process |
      | resolver   | FLAGD_RESOLVER    | ResolverType | IN-PROCESS |
      | resolver   | FLAGD_RESOLVER    | ResolverType | rpc        |
      | resolver   | FLAGD_RESOLVER    | ResolverType | RPC        |
      | host       | FLAGD_HOST        | String       | local      |
      | tls        | FLAGD_TLS         | Boolean      | True       |
      | port       | FLAGD_PORT        | Integer      | 1234       |
      | deadlineMs | FLAGD_DEADLINE_MS | Integer      | 123        |
    @targetURI
    Scenarios: Target URI
      | option    | env              | type   | value |
      | targetUri | FLAGD_TARGET_URI | String | path  |
    @customCert
    Scenarios: Custom Certificates
      | option   | env                    | type   | value |
      | certPath | FLAGD_SERVER_CERT_PATH | String | path  |
    @unixsocket
    Scenarios: Unixsocket
      | option     | env               | type   | value |
      | socketPath | FLAGD_SOCKET_PATH | String | path  |
    @events
    Scenarios: Events
      | option            | env                        | type    | value  |
      | streamDeadlineMs  | FLAGD_STREAM_DEADLINE_MS   | Integer | 500000 |
      | keepAliveTime     | FLAGD_KEEP_ALIVE_TIME_MS   | Long    | 5      |
      | retryBackoffMs    | FLAGD_RETRY_BACKOFF_MS     | Integer | 5000   |
      | retryBackoffMaxMs | FLAGD_RETRY_BACKOFF_MAX_MS | Integer | 12000  |
      | retryGracePeriod  | FLAGD_RETRY_GRACE_PERIOD   | Integer | 10     |
    @sync
    Scenarios: Sync
      | option            | env                        | type    | value    |
      | streamDeadlineMs  | FLAGD_STREAM_DEADLINE_MS   | Integer | 500000   |
      | keepAliveTime     | FLAGD_KEEP_ALIVE_TIME_MS   | Long    | 5        |
      | retryBackoffMs    | FLAGD_RETRY_BACKOFF_MS     | Integer | 5000     |
      | retryBackoffMaxMs | FLAGD_RETRY_BACKOFF_MAX_MS | Integer | 12000    |
      | retryGracePeriod  | FLAGD_RETRY_GRACE_PERIOD   | Integer | 10       |
      | selector          | FLAGD_SOURCE_SELECTOR      | String  | selector |
    @caching
    Scenarios: Caching
      | option       | env                  | type      | value    |
      | cache        | FLAGD_CACHE          | CacheType | disabled |
      | maxCacheSize | FLAGD_MAX_CACHE_SIZE | Integer   | 1236     |
    @offline
    Scenarios: Offline
      | option                | env                            | type    | value |
      | offlineFlagSourcePath | FLAGD_OFFLINE_FLAG_SOURCE_PATH | String  | path  |
      | offlinePollIntervalMs | FLAGD_OFFLINE_POLL_MS          | Integer | 1000  |

  @rpc @in-process
  Scenario Outline: Dedicated Config via Env_var and set
    Given an environment variable "<env>" with value "<env-value>"
    And an option "<option>" of type "<type>" with value "<value>"
    When a config was initialized
    Then the option "<option>" of type "<type>" should have the value "<value>"
    Scenarios:
      | option     | env               | type         | value      | env-value |
      | resolver   | FLAGD_RESOLVER    | ResolverType | in-process | rpc       |
      | host       | FLAGD_HOST        | String       | local      | l         |
      | tls        | FLAGD_TLS         | Boolean      | True       | False     |
      | port       | FLAGD_PORT        | Integer      | 1234       | 3456      |
      | deadlineMs | FLAGD_DEADLINE_MS | Integer      | 123        | 345       |
    @targetURI
    Scenarios: Target URI
      | option    | env              | type   | value | env-value |
      | targetUri | FLAGD_TARGET_URI | String | path  | fun       |
    @customCert
    Scenarios: Custom Certificates
      | option   | env                    | type   | value | env-value |
      | certPath | FLAGD_SERVER_CERT_PATH | String | path  | rpc       |
    @unixsocket
    Scenarios: Unixsocket
      | option     | env               | type   | value | env-value |
      | socketPath | FLAGD_SOCKET_PATH | String | path  | rpc       |
    @events
    Scenarios: Events
      | option            | env                        | type    | value  | env-value |
      | streamDeadlineMs  | FLAGD_STREAM_DEADLINE_MS   | Integer | 500000 | 400       |
      | keepAliveTime     | FLAGD_KEEP_ALIVE_TIME_MS   | Long    | 5      | 4         |
      | retryBackoffMs    | FLAGD_RETRY_BACKOFF_MS     | Integer | 5000   | 4         |
      | retryBackoffMaxMs | FLAGD_RETRY_BACKOFF_MAX_MS | Integer | 12000  | 4         |
      | retryGracePeriod  | FLAGD_RETRY_GRACE_PERIOD   | Integer | 10     | 4         |
    @sync
    Scenarios: Sync
      | option            | env                        | type    | value    | env-value |
      | streamDeadlineMs  | FLAGD_STREAM_DEADLINE_MS   | Integer | 500000   | 400       |
      | keepAliveTime     | FLAGD_KEEP_ALIVE_TIME_MS   | Long    | 5        | 4         |
      | retryBackoffMs    | FLAGD_RETRY_BACKOFF_MS     | Integer | 5000     | 4         |
      | retryBackoffMaxMs | FLAGD_RETRY_BACKOFF_MAX_MS | Integer | 12000    | 4         |
      | retryGracePeriod  | FLAGD_RETRY_GRACE_PERIOD   | Integer | 10       | 4         |
      | selector          | FLAGD_SOURCE_SELECTOR      | String  | selector | sele      |
    @caching
    Scenarios: Caching
      | option       | env                  | type      | value    | env-value |
      | cache        | FLAGD_CACHE          | CacheType | disabled | lru       |
      | maxCacheSize | FLAGD_MAX_CACHE_SIZE | Integer   | 1236     | 2345      |
    @offline
    Scenarios: Offline
      | option                | env                            | type    | value | env-value |
      | offlineFlagSourcePath | FLAGD_OFFLINE_FLAG_SOURCE_PATH | String  | path  | lll       |
      | offlinePollIntervalMs | FLAGD_OFFLINE_POLL_MS          | Integer | 1000  | 4         |
