# GitHub 上传步骤

项目根目录：

```text
C:\Users\Public\genshin_chat
```

## 方式一：命令行上传

1. 在 GitHub 创建一个新仓库。
   - 不要勾选 `Add a README file`
   - 不要勾选 `.gitignore`
   - 不要勾选 `license`

2. 在本地提交：

```powershell
cd C:\Users\Public\genshin_chat
git config user.name "你的 GitHub 名字"
git config user.email "你的 GitHub 邮箱"
git commit -m "Initial release"
```

3. 绑定远程仓库并推送：

```powershell
git remote add origin https://github.com/你的用户名/你的仓库名.git
git push -u origin main
```

如果 GitHub 要求登录，按提示在浏览器里授权即可。

## 方式二：GitHub Desktop 上传

1. 打开 GitHub Desktop。
2. 选择 `File -> Add local repository`。
3. 目录选择：

```text
C:\Users\Public\genshin_chat
```

4. 写提交信息，例如 `Initial release`。
5. 点击 `Commit to main`。
6. 点击 `Publish repository`。

## APK 分发

APK 不建议直接提交到仓库。建议上传到 GitHub Releases：

1. 打开仓库页面。
2. 点击右侧 `Releases`。
3. 点击 `Create a new release`。
4. Tag 填 `v1.9.0`。
5. 上传本地 APK：

```text
C:\Users\Public\genshin_chat\teyvat-chat-release.apk
```

或者使用 GitHub Actions 自动构建出来的 artifact。

## 提交前检查

```powershell
flutter analyze
git status --short --ignored
```

确认以下内容没有进入提交：

- API Key
- `build/`
- `.dart_tool/`
- `.claude/`
- `tools/.cache/`
- `teyvat-chat-release.apk`
- `android/local.properties`
