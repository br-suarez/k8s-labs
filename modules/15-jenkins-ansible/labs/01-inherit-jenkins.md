# Lab 15.01 — Inherit a Jenkins

**CORE · 55 min**

## Context

You are not building a Jenkins practice. You are simulating the situation you
will actually meet: a controller someone else set up, a pipeline nobody
remembers writing, and a need to operate it safely while you plan.

## The problem

### Part 1 — stand it up

```bash
docker run -d --name jenkins -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  jenkins/jenkins:lts-jdk21
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

Add one agent. Note what it took.

1. Where does Jenkins keep its configuration? What does that mean for backup,
   and for reproducing this controller?
2. Compare the setup effort against GitHub Actions, where there is no controller
   at all. What did you trade for that?

Question 2 has a real answer both ways: a controller you run is a controller you
control, and one you must patch, back up and secure.

### Part 2 — read the inherited pipeline

Use `labs/inherited/Jenkinsfile`. Do not fix anything yet — read it and answer:

3. What triggers it? Under what conditions does it deploy to production?
4. What credentials does it use, and how are they injected?
5. Where does it depend on state on the agent — tools installed by hand, files in
   the workspace, a cached directory?
6. What would break if the agent were replaced with a fresh one?

Question 6 is the standard failure of an inherited Jenkins, and it is why
"it works on the old agent" is such a common sentence.

### Part 3 — find the two credential leaks

There are two ways this pipeline exposes a secret in its build log. Find both.

7. What are they? Reproduce each and capture the log line.
8. Fix them. What is the general rule?

### Part 4 — operate it

9. A build is hung. How do you find out what it is waiting on, without killing
   it?
10. Where are the logs of the controller itself, and what would you look at if
    builds started queuing and never starting?
11. The controller needs a restart. How do you do it without losing a running
    build?

## Expected outcome

A running controller and agent, the inherited pipeline read and documented, both
credential leaks reproduced and fixed, and the three operational questions
answered.

## Staged hints

<details><summary>Hint 1 — question 7</summary>

The classic pair: `sh "curl -H 'Authorization: Bearer ${TOKEN}' ..."` where the
command is echoed before execution, and `set -x` or `sh` with `-x` in a block
where a credential is in the environment. Jenkins masks values it knows are
credentials in *some* contexts, and interpolating one into a shell string in
Groovy defeats that masking. The rule: pass secrets as environment variables and
reference them inside single quotes so Groovy never interpolates them.
</details>

<details><summary>Hint 2 — question 5</summary>

Look for absolute paths, tools invoked without a version, anything assuming a
directory exists between builds, and `deleteDir()` being absent. Each one is a
reason the pipeline cannot move to a fresh agent, and together they are why the
migration in lab 02 is harder than translating syntax.
</details>
