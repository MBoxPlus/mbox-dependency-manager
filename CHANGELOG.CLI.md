# 2022/02/22
[Fixed] 组件名称匹配忽略大小写、中划线和下划线，部分平台的组件名有点混乱

[Fixed] 导入新 Feature 现在可以正确更新 Dependency Change 了

[Fixed] 修复 `mbox depend` 编辑模式无法正常使用

[Optimize] 搜索组件会尝试搜索依赖树，如果没有搜索到，现在会尝试搜索所有组件

[Change] 添加组件到本地，仓库名称优先使用 git 的名字，不使用组件名，避免单仓库多组件的名字变化

[Change] 激活所有组件可以采用通配符，例如激活所有组件使用命令：`mbox activate *`，激活仓库 A 下所有组件可以使用命令：`mbox activate A/*`。注意，zsh 下，`*` 是有特殊意义，需要使用 `\` 进行转义，例如 `mbox activate \*`。