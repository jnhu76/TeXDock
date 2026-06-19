# TeXDock 功能模块实施计划

> **For Hermes:** Use subagent-driven-development skill to implement these plans task-by-task.

**目标：** 为 TeXDock 添加 SSO/LDAP/沙箱编译/PG历史/GPU加速/资源监控/编译缓存/多语言包/编译队列/OIDC 等功能模块

**架构：** 基于 Overleaf CE 微服务架构，通过配置启用现有功能，通过新增模块扩展能力

**技术栈：** Node.js, Express, MongoDB, Redis, PostgreSQL, Docker, Passport.js, Bull Queue

---

## 计划结构

| 阶段 | 模块 | 复杂度 | 文件 |
|------|------|--------|------|
| **Phase 1** | LDAP 启用 | ⬜⬜⬜⬜⬜ 1 | [phase1-ldap.md](./phase1-ldap.md) |
| **Phase 1** | SSO/SAML 启用 | ⬜⬜⬜⬜⬜ 1 | [phase1-sso.md](./phase1-sso.md) |
| **Phase 1** | 沙箱编译启用 | ⬜⬜⬜⬜⬜ 1 | [phase1-sandbox.md](./phase1-sandbox.md) |
| **Phase 2** | PostgreSQL/history-v1 (可选) | ⬛⬜⬜⬜⬜ 2 | [phase2-history-pg.md](./phase2-history-pg.md) |
| **Phase 3** | 资源监控 | ⬛⬛⬜⬜⬜ 3 | [phase3-resource-monitor.md](./phase3-resource-monitor.md) |
| **Phase 3** | 编译结果缓存增强 | ⬛⬛⬜⬜⬜ 3 | [phase3-compile-cache.md](./phase3-compile-cache.md) |
| **Phase 4** | GPU 加速 | ⬛⬛⬛⬜⬜ 3 | [phase4-gpu-acceleration.md](./phase4-gpu-acceleration.md) |
| **Phase 4** | 多语言包支持 | ⬛⬛⬛⬛⬜ 4 | [phase4-multilang-packages.md](./phase4-multilang-packages.md) |
| **Phase 5** | 编译队列 | ⬛⬛⬛⬛⬜ 4 | [phase5-compile-queue.md](./phase5-compile-queue.md) |
| **Phase 5** | OIDC | ⬛⬛⬛⬛⬜ 4 | [phase5-oidc.md](./phase5-oidc.md) |

---

## 共享约定

### 本地部署约束

- **无 HTTPS**：所有服务使用 HTTP 协议
- **无证书**：SAML/OIDC 可能需要自签名证书或跳过证书验证
- **本地网络**：服务间通信使用 `127.0.0.1` 或 Docker 内部网络
- **开发环境**：使用 `http://localhost` 作为站点地址

### 代码规范

- 遵循现有代码风格（2 空格缩进，无分号，单引号）
- 新文件放在对应 Feature 目录下
- 测试文件放在 `test/unit/src/` 或 `test/acceptance/`
- 迁移文件命名为 `YYYYMMDDHHMMSS_description.mjs`

### 测试命令

```bash
# 单元测试
cd services/web && npm test

# CLSI 测试
cd services/clsi && npm test

# E2E 测试
cd server-ce && npm test

# 类型检查
cd services/web && npx tsc --noEmit
```

### Git 提交规范

```
feat: 新功能
fix: 修复
docs: 文档
test: 测试
refactor: 重构
chore: 构建/工具
```

---

## 执行顺序建议

```
Phase 1 (配置启用)     ──→  Phase 2 (基础设施)
       │                          │
       ▼                          ▼
Phase 3 (增强模块)     ──→  Phase 4 (高级功能)
       │                          │
       ▼                          ▼
              Phase 5 (系统级改造)
```

每个 Phase 内的模块可并行开发。

---

## 文档索引

| 文档 | 说明 |
|------|------|
| [SUMMARY.md](./SUMMARY.md) | 实施总结和快速开始 |
| [phase1-ldap.md](./phase1-ldap.md) | LDAP 启用详细计划 |
| [phase1-sso.md](./phase1-sso.md) | SSO/SAML 启用详细计划 |
| [phase1-sandbox.md](./phase1-sandbox.md) | 沙箱编译启用详细计划 |
| [phase2-history-pg.md](./phase2-history-pg.md) | PostgreSQL/history-v1 详细计划 |
| [phase3-resource-monitor.md](./phase3-resource-monitor.md) | 资源监控详细计划 |
| [phase3-compile-cache.md](./phase3-compile-cache.md) | 编译结果缓存增强详细计划 |
| [phase4-gpu-acceleration.md](./phase4-gpu-acceleration.md) | GPU 加速详细计划 |
| [phase4-multilang-packages.md](./phase4-multilang-packages.md) | 多语言包支持详细计划 |
| [phase5-compile-queue.md](./phase5-compile-queue.md) | 编译队列详细计划 |
| [phase5-oidc.md](./phase5-oidc.md) | OIDC 详细计划 |
