# MBox Dependency Manager

其他语言：[English](./README.md)

MBox 的 DependencyManager 插件，提供 MBox 依赖管理能力。

该插件只是依赖管理工具的基础库，需要具体的依赖管理工具提供支持。例如 `MBoxRuby` 和 `MBoxCocoapods`.

## Command

### 1. mbox depend

查询/修改 MBox 控制的依赖变动

```shell
$ mbox depend AFNetworking --version 2.0

$ mbox depend AFNetworking --git git@xxx.com:xx/xx.git --branch develop
```

注意：该命令只是提供了一个抽象的操作入口，只是简单的操作配置，并不会直接生效，具体生效需要具体的依赖管理工具进行支持。

### 2. mbox activate/deactivate

激活/取消 某个(些)组件。当仓库在本地的时候：

1. 如果组件是激活态，则会使用本地的组件代码；
1. 如果组件是非激活态，则不会使用本地代码，而是下载远端线上版本。

```shell
# 使用本地的 AFNetworking 组件代码
$ mbox activate AFNetworking

# 不使用本地的 AFNetworking 组件代码，使用线上版本
$ mbox deactivate AFNetworking
```

注意：该命令只是提供了一个抽象的操作入口，只是简单的操作配置，并不会直接生效，具体生效需要具体的依赖管理工具进行支持。

## Dependency

该插件只能在 Workspace 下生效

依赖的 MBox 组件：

1. MBoxCore
1. MBoxGit
1. MBoxWorkspace

## 激活插件

该插件无需手动激活，一般由具体的依赖管理工具引入

## Contributing
Please reference the section [Contributing](https://github.com/MBoxPlus/mbox#contributing)

## License
MBox is available under [GNU General Public License v2.0 or later](./LICENSE).
