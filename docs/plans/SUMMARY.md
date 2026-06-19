# TeXDock 功能模块实施总结

## 文档结构

```
docs/plans/
├── README.md                      # 总览和共享约定
├── SUMMARY.md                     # 本文档
├── QUICKSTART.md                  # 快速开始指南
├── phase1-ldap.md                 # Phase 1: LDAP 启用
├── phase1-sso.md                  # Phase 1: SSO/SAML 启用
├── phase1-sandbox.md              # Phase 1: 沙箱编译启用
├── phase2-history-pg.md           # Phase 2: PostgreSQL/history-v1
├── phase3-resource-monitor.md     # Phase 3: 资源监控
├── phase3-compile-cache.md        # Phase 3: 编译结果缓存增强
├── phase4-gpu-acceleration.md     # Phase 4: GPU 加速
├── phase4-multilang-packages.md   # Phase 4: 多语言包支持
├── phase5-compile-queue.md        # Phase 5: 编译队列
└── phase5-oidc.md                 # Phase 5: OIDC
```

## 已有 API 端点参考

### Web 服务端点（`services/web/app/src/router.mjs`）

| 方法 | 路径 | Handler | 说明 |
|------|------|---------|------|
| GET | `/login` | `UserPagesController.loginPage` | 登录页面 |
| POST | `/login` | `AuthenticationController.passportLogin` | 登录处理 |
| POST | `/logout` | `UserController.logout` | 登出 |
| GET | `/register` | `UserPagesController.registerPage` | 注册页面 |
| POST | `/register` | `UserRegistrationHandler.registerNewUser` | 注册处理 |
| GET | `/user/settings` | `UserPagesController.settingsPage` | 设置页面 |
| POST | `/user/settings` | `UserController.updateUserSettings` | 更新设置 |
| POST | `/user/password/update` | `UserController.changePassword` | 修改密码 |
| GET | `/user/emails` | `UserEmailsController.list` | 邮箱列表 |
| POST | `/user/emails/confirm` | `UserEmailsController.confirm` | 确认邮箱 |

### 编译相关端点（`services/web/app/src/router.mjs`）

| 方法 | 路径 | Handler | 说明 |
|------|------|---------|------|
| POST | `/project/:id/compile` | `CompileController.compile` | 编译项目 |
| POST | `/project/:id/compile/stop` | `CompileController.stopCompile` | 停止编译 |
| GET | `/project/:id/output/cached/output.overleaf.json` | `ClsiCacheController.getLatestBuildFromCache` | 获取缓存 |
| GET | `/project/:id/sync/code` | `CompileController.proxySyncCode` | 代码同步 |
| GET | `/project/:id/sync/pdf` | `CompileController.proxySyncPdf` | PDF 同步 |
| GET | `/project/:id/wordcount` | `CompileController.wordCount` | 字数统计 |
| DELETE | `/project/:id/output` | `CompileController.deleteAuxFiles` | 删除辅助文件 |

### CLSI 服务端点（`services/clsi/app.js`）

| 方法 | 路径 | Handler | 说明 |
|------|------|---------|------|
| POST | `/project/:project_id/compile` | `CompileController.compile` | 编译 |
| POST | `/project/:project_id/compile/stop` | `CompileController.stopCompile` | 停止编译 |
| GET | `/project/:project_id/sync/code` | `CompileController.syncFromCode` | 代码同步 |
| GET | `/project/:project_id/sync/pdf` | `CompileController.syncFromPdf` | PDF 同步 |
| GET | `/project/:project_id/wordcount` | `CompileController.wordcount` | 字数统计 |
| GET | `/project/:project_id/status` | `CompileController.status` | 编译状态 |
| DELETE | `/project/:project_id` | `CompileController.clearCache` | 清除缓存 |
| GET | `/status` | 健康检查 | CLSI 存活检查 |

## 已有前端组件复用

### SSO 相关组件

| 组件 | 路径 | 用途 | 复用方式 |
|------|------|------|----------|
| `SSOProvider` | `features/settings/context/sso-context.tsx` | SSO 上下文 | OIDC 直接复用 |
| `SSOLinkingWidget` | `features/settings/components/linking/sso-widget.tsx` | SSO 链接/解绑 | OIDC 直接复用 |
| `SSOAlert` | `features/settings/components/emails/sso-alert.tsx` | SSO 状态提示 | OIDC 直接复用 |
| `LinkingSection` | `features/settings/components/linking-section.tsx` | 集成链接区域 | OIDC 直接复用 |
| `SecuritySection` | `features/settings/components/security-section.tsx` | 安全设置 | OIDC 直接复用 |
| `SettingsPageRoot` | `features/settings/components/root.tsx` | 设置页面入口 | OIDC 直接复用 |

### 编译相关组件

| 组件 | 路径 | 用途 | 复用方式 |
|------|------|------|----------|
| `CompilerSettings` | `features/ide-redesign/components/settings/compiler-settings/compiler-settings.tsx` | 编译设置入口 | GPU/包管理复用 |
| `CompilerSetting` | `features/ide-redesign/components/settings/compiler-settings/compiler-setting.tsx` | 编译器选择 | 直接复用 |
| `ImageNameSetting` | `features/ide-redesign/components/settings/compiler-settings/image-name-setting.tsx` | TeX Live 版本 | GPU 复用 |
| `AutoCompileSetting` | `features/ide-redesign/components/settings/compiler-settings/auto-compile-setting.tsx` | 自动编译 | 直接复用 |
| `StopOnFirstErrorSetting` | `features/ide-redesign/components/settings/compiler-settings/stop-on-first-error-setting.tsx` | 首次错误停止 | 直接复用 |
| `DocumentCompiler` | `features/pdf-preview/util/compiler.js` | 编译请求发送 | 队列改造复用 |
| `LocalCompileContext` | `shared/context/local-compile-context.tsx` | 编译状态管理 | 队列改造复用 |

### 通用 UI 组件

| 组件 | 路径 | 用途 |
|------|------|------|
| `OLButton` | `features/ui/components/ol/ol-button` | 按钮 |
| `OLModal` | `features/ui/components/ol/ol-modal` | 模态框 |
| `OLNotification` | `features/ui/components/ol/ol-notification` | 通知 |
| `OLFormGroup` | `features/ui/components/ol/ol-form-group` | 表单组 |
| `OLFormSwitch` | `features/ui/components/ol/ol-form-switch` | 开关 |
| `SettingsSection` | `features/ide-redesign/components/settings/settings-section` | 设置分区 |
| `ToggleSetting` | `features/ide-redesign/components/settings/toggle-setting` | 开关设置 |
| `DropdownSetting` | `features/ide-redesign/components/settings/dropdown-setting` | 下拉设置 |

## 已有后端模块复用

### 认证模块

| 模块 | 路径 | 用途 | 复用方式 |
|------|------|------|----------|
| `SAMLIdentityManager` | `Features/User/SAMLIdentityManager.js` | SAML 身份管理 | OIDC 参考其接口设计 |
| `ThirdPartyIdentityManager` | `Features/User/ThirdPartyIdentityManager.js` | 第三方身份管理 | OIDC 直接复用 |
| `Features` | `infrastructure/Features.js` | 功能开关 | OIDC 添加新 flag |

### 编译模块

| 模块 | 路径 | 用途 | 复用方式 |
|------|------|------|----------|
| `CompileManager` | `Features/Compile/CompileManager.js` | 编译业务逻辑 | 队列改造 |
| `ClsiManager` | `Features/Compile/ClsiManager.js` | CLSI 请求构建 | 队列改造 |
| `CompileController` | `Features/Compile/CompileController.js` | HTTP 处理器 | 新增进度端点 |

### 监控模块

| 模块 | 路径 | 用途 | 复用方式 |
|------|------|------|----------|
| `Metrics` | `@overleaf/metrics` | Prometheus 指标 | 资源监控直接复用 |
| `Logger` | `@overleaf/logger` | 日志 | 所有新模块复用 |
| `RateLimiter` | `infrastructure/RateLimiter.js` | 限流 | 包管理 API 复用 |

## 数据流图

### 编译流程（现有）

```
用户点击编译
    ↓
前端 DocumentCompiler.compile()
    ↓
POST /project/:id/compile
    ↓
Web CompileController.compile()
    ↓
Web CompileManager.compile()
    ↓ (构建请求)
Web ClsiManager.sendRequest()
    ↓ (HTTP POST)
CLSI CompileController.compile()
    ↓
CLSI CompileManager.doCompile()
    ↓ (文件同步)
CLSI ResourceWriter.writeResources()
    ↓ (执行编译)
CLSI LatexRunner.runLatex()
    ↓ (Docker/Local)
CommandRunner.run()
    ↓
输出文件 → OutputCacheManager
    ↓
响应 → 前端渲染 PDF
```

### SSO 登录流程（现有）

```
用户点击 SSO 登录
    ↓
GET /saml/login
    ↓
Passport SAML Strategy
    ↓ (重定向到 IdP)
用户在 IdP 登录
    ↓ (SAML 断言)
POST /saml/acs
    ↓
SAMLIdentityManager.getUser()
    ↓ (查找/创建用户)
AuthenticationController.finishLogin()
    ↓
设置 session → 重定向到首页
```

### 新增：编译队列流程（Phase 5）

```
用户点击编译
    ↓
前端 DocumentCompiler.compile()
    ↓
POST /project/:id/compile
    ↓
Web CompileController.compile()
    ↓
Web CompileManager.compile()
    ↓ (入队)
CompileQueue.addJob()
    ↓ (Redis Bull)
CompileWorker.process()
    ↓ (异步)
ClsiManager.sendRequest()
    ↓
CLSI 编译...
    ↓
WebSocket 推送进度
    ↓
前端 LocalCompileContext 更新状态
```

## 实施概览

| 阶段 | 模块 | 难度 | 工期 | 代码量 | 复用组件 |
|------|------|------|------|--------|----------|
| Phase 1 | LDAP 启用 | ⬜⬜⬜⬜⬜ 1 | 1 天 | 28 行 | `passport-ldapauth` |
| Phase 1 | SSO/SAML 启用 | ⬜⬜⬜⬜⬜ 1 | 1-2 天 | 61-91 行 | `SSOLinkingWidget`, `SSOProvider` |
| Phase 1 | 沙箱编译启用 | ⬜⬜⬜⬜⬜ 1 | 1-2 天 | 38 行 | `DockerRunner` |
| Phase 2 | PostgreSQL/history-v1 (可选) | ⬛⬜⬜⬜⬜ 2 | 3-5 天 | 200-400 行 | `knex`, 双后端架构 |
| Phase 3 | 资源监控 | ⬛⬛⬜⬜⬜ 3 | 5-10 天 | 400-800 行 | `@overleaf/metrics`, Docker API |
| Phase 3 | 编译结果缓存增强 | ⬛⬛⬜⬜⬜ 3 | 3-5 天 | 200-500 行 | `OutputCacheManager` |
| Phase 4 | GPU 加速 | ⬛⬛⬛⬜⬜ 3 | 5-8 天 | 300-600 行 | `DockerRunner`, `ImageNameSetting` |
| Phase 4 | 多语言包支持 | ⬛⬛⬛⬛⬜ 4 | 8-15 天 | 500-1000 行 | `CompilerSettings`, `DropdownSetting` |
| Phase 5 | 编译队列 | ⬛⬛⬛⬛⬜ 4 | 10-20 天 | 600-1200 行 | `Bull`, `CompileManager` |
| Phase 5 | OIDC | ⬛⬛⬛⬛⬜ 4 | 12-20 天 | 800-1500 行 | `SSOLinkingWidget`, `ThirdPartyIdentityManager` |
| | **合计** | | **49-88 天** | **3130-6330 行** | |

## 本地部署约束

所有计划都考虑了以下本地部署约束：

1. **无 HTTPS**：所有服务使用 HTTP 协议
   - OIDC/SAML 配置使用 `http://` 前缀
   - 设置 `NODE_TLS_REJECT_UNAUTHORIZED=0` 跳过证书验证
2. **无证书**：SAML/OIDC 可能需要自签名证书或跳过证书验证
3. **本地网络**：服务间通信使用 `127.0.0.1` 或 Docker 内部网络
4. **开发环境**：使用 `http://localhost` 作为站点地址

## 依赖关系

```
Phase 1 (配置启用)     ──→  Phase 2 (基础设施)
       │                          │
       ▼                          ▼
Phase 3 (增强模块)     ──→  Phase 4 (高级功能)
       │                          │
       ▼                          ▼
              Phase 5 (系统级改造)
```

## 验证清单

### Phase 1 验证

- [ ] LDAP 登录按钮可见
- [ ] SSO 登录按钮可见
- [ ] 沙箱编译工作正常
- [ ] 所有配置语法验证通过

### Phase 2 验证（可选）

> **注意：** PostgreSQL 是可选增强，CE 版完全不需要。不配置 `HISTORY_CONNECTION_STRING` 即可跳过。

- [ ] PostgreSQL 容器运行正常（如启用）
- [ ] 数据库迁移成功（如启用）
- [ ] 版本历史功能正常（CE 用 MongoDB 后端）

### Phase 3 验证

- [ ] 资源监控指标可访问
- [ ] Prometheus 端点返回数据
- [ ] 缓存命中率提升

### Phase 4 验证

- [ ] GPU 检测正常
- [ ] GPU 加速编译工作正常
- [ ] 包管理 API 可用

### Phase 5 验证

- [ ] 编译队列工作正常
- [ ] WebSocket 进度推送正常
- [ ] OIDC 登录流程完整
- [ ] 所有单元测试通过
