# 铁镌 R Iron Etch R

受限源码维护仓库。用于本地开发、学习和提交改进，不提供任何正式发行版或分发授权。

## 开发构建

```powershell
flutter pub get
flutter analyze
flutter build apk --debug
```

安装调试包：

```powershell
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

## 功能

- 训练记录、做功计算、历史编辑与状态电量
- AI 教练、训练分析和知识库
- 动作库与动作示意图
- 视频合集与 UP 主管理
- 书库、EPUB 导入与阅读器
- 主题工坊、明暗模式和自定义背景
- 本地持久化、云同步与数据导入导出

## 环境要求

- Android 5.0 及以上
- Flutter 3.47.9 / Dart 3.13.7
- Gradle 9.2.0、Android Gradle Plugin 9.0.1、Kotlin 2.3.20
- compileSdk 36

## 目录结构

```text
lib/
  main.dart                 应用入口、主页与训练记录
  providers/                主题、设置、训练数据等状态
  screens/                  历史、设置、主题、书库、视频、AI 教练等页面
  services/                 云同步、EPUB、B 站、AI、知识库、做功计算
  theme/                    主题定义
  widgets/                  通用 UI 组件
assets/
  exercises/                动作示意图
  images/                   启动与背景图片
  icon/app_icon.png         应用图标
  coach_rules.json          AI 教练知识库
  bili_list.json            B 站视频合集
```

## 许可证

本仓库采用受限源码可见许可，不是开源许可。

- 允许查看、个人学习和评估
- 允许在本地编译用于个人测试
- 允许向本仓库提交贡献
- 禁止商用、再分发、发布任何构建、上架任何平台或制作衍生发行版
- 禁止使用“铁镌 / Iron Etch”名称和图标暗示官方授权

详见 `LICENSE`、`NOTICE`、`TRADEMARK.md`。

本仓库不提供正式发行包，也不附带任何发布或分发流程。

仓库内以 Git LFS 形式提供 `assets/books/iron_book.epub`，开源版默认从本仓库的公开媒体地址下载该书。也可以通过 `--dart-define=IRON_BOOK_URL=...` 覆盖下载地址，或直接在书库中导入本地 EPUB。
