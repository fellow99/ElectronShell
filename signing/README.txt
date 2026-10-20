signingConfigs 说明（重要）
===========================

本项目**不使用** build-profile.json5 中的 `app.signingConfigs` 字段，原因：

hvigor 的 `SignHap` 任务对 `storePassword` / `keyPassword` 有硬性校验——要求长度
不小于 32 个字符，即必须是 DevEco Studio「Project Structure > Signing Configs」
自动签名时写入的加密密文。命令行无法直接填写明文口令，也无法离线复现该密文。

因此本项目的签名流程是：

1. `hvigorw assembleHap` 只负责构建**未签名** HAP
   → `electron/build/default/outputs/default/electron-default-unsigned.hap`
2. `scripts/build.sh` 再调用 SDK 自带的 `hap-sign-tool.jar sign-app`
   用 `signing/` 目录下的材料（明文口令）完成签名
   → `electron/build/default/outputs/default/electron-default-signed.hap`

如果你希望改用 DevEco Studio 图形界面自动签名，可以在
Project Structure > Project > Signing Configs 中勾选「Automatically generate signature」，
DevEco 会自动把 `signingConfigs` 写回 build-profile.json5（此后 `scripts/build.sh`
的 sign-app 步骤可与 hvigor 自带签名二选一）。
