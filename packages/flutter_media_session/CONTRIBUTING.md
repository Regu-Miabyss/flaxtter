# 🤝 Contributing to flutter_media_session

First off, thank you for considering contributing to `flutter_media_session`! It's people like you who make this project better for everyone.

---

## 🛠️ Development Environment

To ensure compatibility, please use the following SDK versions:

- **Flutter SDK**: `>= 3.3.0`
- **Dart SDK**: `>= 3.3.0 < 4.0.0`

Testing on physical devices is highly recommended, especially for Android and iOS background behavior.

---

## 🐛 Issues

Before creating a new issue, please search existing issues to see if it has already been reported.

### Bug Reports
- Use a clear and descriptive title.
- Provide a minimal reproduction code snippet (MRE).
- List the affected platforms (Android, iOS, etc.) and device models.
- Include `flutter doctor -v` output.

### Feature Requests
- Describe the feature you'd like to see and why it's useful.
- If possible, suggest an API design that fits the current plugin structure.

> [!TIP]
> Always open an issue to discuss significant changes before starting work on a PR.

---

## 🚀 Pull Requests

When you're ready to contribute code, follow these steps:

### 1. Pre-requisites
- **Fork** the repository and create your branch from `main`.
- Ensure your code follows the `flutter_lints` rules.
- **Discuss First**: Unless it's a minor fix (typos, small bug fixes), there should be an associated issue discussed beforehand.

### 2. PR Permissions
When opening a Pull Request, **ensure that "Allow edits from maintainers" is checked**.

> [!IMPORTANT]
> This is a mandatory requirement. It allows us to help with rebasing or minor adjustments to get your code merged faster.

### 3. Formatting
We use structured titles for PRs and commit messages:

Format: `<type>(<platform>): <description>`

- **Types**: `feat`, `fix`, `docs`, `refactor`, `style`, `test`, `chore`.
- **Platforms**: `android`, `ios`, `macos`, `windows`, `web`, `all`, `core`.

**Example**: `feat(android): add support for custom media actions`

---

## 📜 License

By contributing, you agree that your contributions will be licensed under the [MIT License](https://github.com/wyrindev/flutter-media-session/blob/main/LICENSE).