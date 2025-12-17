# Contributing

Thanks for your interest in contributing! This project uses the **Developer Certificate of Origin (DCO)** and requires a Signed-off-by line on all commits.

## How to Contribute
1. **Fork** the repository and create your feature branch:
   ```bash
   git checkout -b feature/<short-description>
   ```
2. Make your changes and ensure they build and run.
3. **Commit with DCO**:
   ```bash
   git commit -s -m "feat(ui): add project selector"
   ```
   The `-s` flag adds the Signed-off-by line automatically.
4. **Push** your branch and open a **Pull Request**.

## Developer Certificate of Origin (DCO)

```
Developer Certificate of Origin
Version 1.1

By making a contribution to this project, I certify that:

(a) The contribution was created in whole or in part by me and I have the right
    to submit it under the open source license indicated in the file; or
(b) The contribution is based upon previous work that, to the best of my knowledge,
    is covered under an appropriate open source license and I have the right under
    that license to submit that work with modifications, whether created in whole
    or in part by me, under the same open source license (unless I am permitted
    to submit under a different license), as indicated in the file; or
(c) The contribution was provided directly to me by some other person who certified
    (a), (b), or (c) and I have not modified it.
(d) I understand and agree that this project and the contribution are public and
    that a record of the contribution (including all personal information I submit
    with it, including my sign-off) is maintained indefinitely and may be redistributed
    consistent with this project or the open source license(s) involved.
```

## Commit Message Guidelines
- Use a concise subject, e.g., `feat(build): add kas workdir guard`.
- Include context in the body when needed.
- Always include `Signed-off-by: Your Name <your.email@example.com>`.

## Code Style & PR Checklist
- Small, focused commits
- Tested locally
- Update docs when behavior changes
- Link issues in PR description if applicable

## Reporting Issues
Open a GitHub Issue with:
- Steps to reproduce
- Logs (first ~40 lines)
- Environment details (Docker version, host OS, disk space)
