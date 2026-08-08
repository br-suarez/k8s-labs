# Inherited pipeline

The `Jenkinsfile` here is the one lab 15.01 asks you to read and lab 15.02 asks
you to migrate. It is deliberately representative rather than deliberately bad —
every problem in it appears in real inherited pipelines.

Do not read the solutions below until you have worked through lab 15.01 part 3.

<details><summary>What to look for (spoiler)</summary>

- Two credential exposure paths, by different mechanisms
- Agent state: a hardcoded absolute workspace path, a Go toolchain installed by
  hand at a fixed location, and a `PATH` assumption
- A mutable tag as the artifact identity — the module 09 lesson
- `pollSCM` instead of a webhook
- No `concurrency` equivalent
- No cleanup between builds

</details>
