My learning memo of [cabol/erlbus](https://github.com/cabol/erlbus).

## Process design

```

                                            ┌───────────┐
                                            │   ebus    │
                                            └───────────┘
                                                  │
                                                  │
                                  ┌──────────────────────────────┐
                                  │      ebus_ps_local_sup       │
                                  └──────────────────────────────┘
                                                  │
                                                  │
                                  ┌──────────────────────────────┐
                                  │       ebus_supervisor        │
                                  └──────────────────────────────┘
                                                  │
                                                  │
                                 ┌────────────────┴─────────────────────────────┐
                                 │                                              │
                                 │                                              │
                 ┌──────────────────────────────┐   ┌───────────────────────────────────────────────────────┐
                 │        ebus_ps_local         │   │                                                       │
                 └──────────────────────────────┘   │                      ebus_ps_gc                       │
                                                    │                     <gen_server>                      │
                                                    │                                                       │
                                                    │                (1) down(GCServer, Pid)                │
                                                    │        Remove an object from management table         │
                                                    │               of subscribers and topics               │
                                                    │               when subscriber is down.                │
                                                    │                                                       │
                                                    │  (2) unsubscribe(Pid, Topic, TopicsTable, PidsTable)  │
                                                    │       Remove subscriber info from topics table        │
                                                    │              and remove subscriber info               │
                                                    │              from subscriber table also               │
                                                    │                                                       │
                                                    │                                                       │
                                                    └───────────────────────────────────────────────────────┘
```
