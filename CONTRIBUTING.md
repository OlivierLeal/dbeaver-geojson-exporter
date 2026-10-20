# Contributing to DBeaver GeoJSON Exporter

Thank you for considering contributing to **DBeaver GeoJSON Exporter**! 🎉

## How to Contribute

### Reporting Bugs
- Ensure the bug wasn't already reported by searching through existing [Issues](https://github.com).
- Open an issue using the **Bug report** template.
- Include query examples, SRID details, and stack traces from your DBeaver logs (`.metadata/.log`).

### Suggesting Enhancements
- Open an issue using the **Feature request** template.
- Explain the use case and why this enhancement would be useful to other GIS users.

### Submitting a Pull Request (PR)
1. Fork the repository.
2. Create a new branch: `git checkout -b feature/my-new-feature`
3. Make your changes and test them locally:
   ```bash
   ./build.sh
   sudo ./install.sh
   ```
4. Commit your changes: `git commit -am 'Add some feature'`
5. Push to the branch: `git push origin feature/my-new-feature`
6. Open a Pull Request.

---

## Coding Standards
- Target Java 17+ compatibility.
- Adhere to the **RFC 7946** GeoJSON specification (right-hand rule for polygon rings, WGS84 coordinates).
- Keep dependencies minimal — leverage DBeaver's built-in OSGi bundles and JTS libraries.
