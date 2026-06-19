# Phase 5: OIDC 实施计划

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**目标：** 添加 OpenID Connect 单点登录支持

**架构：** 基于现有 SSO 架构，新增 OIDC 协议支持

**技术栈：** passport-openidconnect, openid-client, Express, MongoDB

**预计工期：** 12-20 天

**本地部署注意：**
- 无 HTTPS：OIDC 可能需要配置允许 HTTP
- 无证书：使用自签名证书或跳过证书验证
- 测试环境：使用本地 OIDC Provider

---

### Task 1: 扩展 SSOConfig 模型

**目标：** 添加 OIDC 相关字段到 SSOConfig

**文件：**
- 修改: `services/web/app/src/models/SSOConfig.js`

**步骤 1: 修改模型**

```javascript
// services/web/app/src/models/SSOConfig.js 修改
const SSOConfigSchema = new Schema({
  // 现有 SAML 字段
  entryPoint: { type: String },
  certificates: [{ type: String }],
  userIdAttribute: { type: String },
  userFirstNameAttribute: { type: String },
  userLastNameAttribute: { type: String },

  // 新增 OIDC 字段
  protocol: { 
    type: String, 
    enum: ['saml', 'oidc'], 
    default: 'saml' 
  },
  issuerUrl: { type: String },           // OIDC Issuer URL
  clientId: { type: String },            // OIDC Client ID
  clientSecret: { type: String },        // OIDC Client Secret
  redirectUri: { type: String },         // OIDC Redirect URI
  scopes: [{ type: String }],            // OIDC Scopes
  claimsMapping: { type: Schema.Types.Mixed }, // OIDC Claims 映射

  // 通用字段
  validated: { type: Boolean, default: false },
  enabled: { type: Boolean, default: false }
})
```

**步骤 2: 运行迁移**

创建迁移文件 `tools/migrations/YYYYMMDDHHMMSS_add_oidc_to_sso_config.mjs`：

```javascript
export async function up(db) {
  await db.collection('ssoConfigs').updateMany(
    { protocol: { $exists: false } },
    { $set: { protocol: 'saml' } }
  )
}

export async function down(db) {
  await db.collection('ssoConfigs').updateMany(
    { protocol: 'saml' },
    { $unset: { protocol: 1 } }
  )
}
```

**步骤 3: 提交**

```bash
git add services/web/app/src/models/SSOConfig.js tools/migrations/YYYYMMDDHHMMSS_add_oidc_to_sso_config.mjs
git commit -m "feat: extend SSOConfig model with OIDC fields"
```

---

### Task 2: 创建 OIDCIdentityManager 模块

**目标：** 实现 OIDC 身份管理核心功能

**文件：**
- 创建: `services/web/app/src/Features/User/OIDCIdentityManager.js`

**步骤 1: 编写失败测试**

```javascript
// services/web/test/unit/src/User/OIDCIdentityManagerTests.js
const { expect } = require('chai')
const sinon = require('sinon')
const OIDCIdentityManager = require('../../../../app/src/Features/User/OIDCIdentityManager')

describe('OIDCIdentityManager', function () {
  let manager
  let mockUserGetter
  let mockUserUpdater

  beforeEach(function () {
    mockUserGetter = {
      getUser: sinon.stub()
    }
    mockUserUpdater = {
      updateUser: sinon.stub()
    }
    manager = new OIDCIdentityManager(mockUserGetter, mockUserUpdater)
  })

  describe('getUser', function () {
    it('should find user by OIDC identifier', async function () {
      mockUserGetter.getUser.resolves({
        _id: 'user123',
        thirdPartyIdentifiers: [{
          providerId: 'oidc-test',
          externalUserId: 'sub123'
        }]
      })
      
      const user = await manager.getUser('oidc-test', 'sub123')
      expect(user).to.have.property('_id', 'user123')
    })

    it('should return null when user not found', async function () {
      mockUserGetter.getUser.resolves(null)
      
      const user = await manager.getUser('oidc-test', 'nonexistent')
      expect(user).to.be.null
    })
  })

  describe('linkAccounts', function () {
    it('should link OIDC account to user', async function () {
      mockUserUpdater.updateUser.resolves()
      
      const result = await manager.linkAccounts('user123', {
        providerId: 'oidc-test',
        externalUserId: 'sub123',
        email: 'test@example.com',
        name: 'Test User'
      })
      
      expect(result).to.be.true
      expect(mockUserUpdater.updateUser.calledOnce).to.be.true
    })
  })

  describe('unlinkAccounts', function () {
    it('should unlink OIDC account from user', async function () {
      mockUserUpdater.updateUser.resolves()
      
      const result = await manager.unlinkAccounts('user123', 'oidc-test')
      expect(result).to.be.true
    })
  })
})
```

**步骤 2: 运行测试验证失败**

Run: `cd services/web && npm test -- --grep "OIDCIdentityManager"`
Expected: FAIL - "Cannot find module '../../../../app/src/Features/User/OIDCIdentityManager'"

**步骤 3: 实现最小代码**

```javascript
// services/web/app/src/Features/User/OIDCIdentityManager.js
'use strict'

const logger = require('@overleaf/logger')
const Errors = require('../Errors/Errors')

class OIDCIdentityManager {
  constructor(userGetter, userUpdater) {
    this.UserGetter = userGetter
    this.UserUpdater = userUpdater
  }

  async getUser(providerId, externalUserId) {
    const user = await this.UserGetter.getUser({
      'thirdPartyIdentifiers.providerId': providerId,
      'thirdPartyIdentifiers.externalUserId': externalUserId
    })

    return user
  }

  async linkAccounts(userId, oidcData) {
    const { providerId, externalUserId, email, name, claims } = oidcData

    try {
      await this.UserUpdater.updateUser(userId, {
        $push: {
          thirdPartyIdentifiers: {
            providerId,
            externalUserId,
            externalData: {
              email,
              name,
              claims
            }
          }
        }
      })

      logger.info({ userId, providerId }, 'OIDC account linked')
      return true
    } catch (err) {
      logger.warn({ err, userId, providerId }, 'Failed to link OIDC account')
      throw err
    }
  }

  async unlinkAccounts(userId, providerId) {
    try {
      await this.UserUpdater.updateUser(userId, {
        $pull: {
          thirdPartyIdentifiers: {
            providerId
          }
        }
      })

      logger.info({ userId, providerId }, 'OIDC account unlinked')
      return true
    } catch (err) {
      logger.warn({ err, userId, providerId }, 'Failed to unlink OIDC account')
      throw err
    }
  }

  async updateClaims(userId, providerId, claims) {
    try {
      await this.UserUpdater.updateUser(userId, {
        $set: {
          'thirdPartyIdentifiers.$[elem].externalData.claims': claims
        }
      }, {
        arrayFilters: [{ 'elem.providerId': providerId }]
      })

      return true
    } catch (err) {
      logger.warn({ err, userId, providerId }, 'Failed to update OIDC claims')
      return false
    }
  }

  async getLinkedProviders(userId) {
    const user = await this.UserGetter.getUserById(userId)
    if (!user) {
      return []
    }

    return (user.thirdPartyIdentifiers || [])
      .filter(ident => ident.providerId.startsWith('oidc'))
      .map(ident => ({
        providerId: ident.providerId,
        externalUserId: ident.externalUserId,
        email: ident.externalData?.email,
        name: ident.externalData?.name
      }))
  }
}

module.exports = OIDCIdentityManager
```

**步骤 4: 运行测试验证通过**

Run: `cd services/web && npm test -- --grep "OIDCIdentityManager"`
Expected: PASS

**步骤 5: 提交**

```bash
git add services/web/app/src/Features/User/OIDCIdentityManager.js services/web/test/unit/src/User/OIDCIdentityManagerTests.js
git commit -m "feat: add OIDCIdentityManager for OIDC identity management"
```

---

### Task 3: 创建 OIDC Passport Strategy

**目标：** 实现 OIDC Passport 策略

**文件：**
- 创建: `services/web/app/src/Features/Authentication/OIDCStrategy.js`

**步骤 1: 实现策略**

```javascript
// services/web/app/src/Features/Authentication/OIDCStrategy.js
'use strict'

const { Strategy: OpenIDConnectStrategy } = require('passport-openidconnect')
const logger = require('@overleaf/logger')
const OIDCIdentityManager = require('../User/OIDCIdentityManager')

class OIDCStrategy {
  constructor(app, userMapper, ssoConfig) {
    this.app = app
    this.userMapper = userMapper
    this.ssoConfig = ssoConfig
    this.identityManager = new OIDCIdentityManager()
  }

  async setup() {
    const { issuerUrl, clientId, clientSecret, redirectUri, scopes } = this.ssoConfig

    const strategy = new OpenIDConnectStrategy({
      issuer: issuerUrl,
      authorizationURL: `${issuerUrl}/authorize`,
      tokenURL: `${issuerUrl}/oauth/token`,
      userInfoURL: `${issuerUrl}/userinfo`,
      clientID: clientId,
      clientSecret: clientSecret,
      callbackURL: redirectUri || `${process.env.OVERLEAF_SITE_URL || 'http://localhost'}/oidc/callback`,
      scope: scopes || ['openid', 'profile', 'email']
    }, async (issuer, profile, done) => {
      try {
        const user = await this._findOrCreateUser(issuer, profile)
        done(null, user)
      } catch (err) {
        done(err)
      }
    })

    this.app.use(strategy)
    this._setupRoutes()
  }

  async _findOrCreateUser(issuer, profile) {
    const { id, emails, displayName } = profile
    const email = emails?.[0]?.value

    // 查找现有用户
    let user = await this.identityManager.getUser(issuer, id)

    if (!user) {
      // 创建新用户
      user = await this.userMapper.createUser({
        email,
        name: displayName,
        providerId: issuer,
        externalUserId: id
      })
    }

    // 链接账户
    await this.identityManager.linkAccounts(user._id, {
      providerId: issuer,
      externalUserId: id,
      email,
      name: displayName,
      claims: profile._json
    })

    return user
  }

  _setupRoutes() {
    // 登录路由
    this.app.get('/oidc/login', (req, res) => {
      this.app.authenticate('openidconnect')(req, res)
    })

    // 回调路由
    this.app.get('/oidc/callback',
      this.app.authenticate('openidconnect', {
        successRedirect: '/',
        failureRedirect: '/login'
      })
    )

    // 登出路由
    this.app.get('/oidc/logout', (req, res) => {
      req.logout()
      res.redirect('/')
    })
  }
}

module.exports = OIDCStrategy
```

**步骤 2: 提交**

```bash
git add services/web/app/src/Features/Authentication/OIDCStrategy.js
git commit -m "feat: add OIDC Passport strategy"
```

---

### Task 4: 添加 OIDC 路由

**目标：** 添加 OIDC 相关路由

**文件：**
- 修改: `services/web/app/src/router.mjs`

**步骤 1: 添加路由**

```javascript
// services/web/app/src/router.mjs 添加
const OIDCStrategy = require('./Features/Authentication/OIDCStrategy')

// OIDC 路由
if (Settings.enableOidc) {
  const oidcStrategy = new OIDCStrategy(app, userMapper, Settings.oidc)
  oidcStrategy.setup()
}
```

**步骤 2: 添加环境变量**

```yaml
# docker-compose.yml 添加
OVERLEAF_OIDC_ENABLED: "true"
OVERLEAF_OIDC_ISSUER_URL: "http://localhost:8080/realms/master"
OVERLEAF_OIDC_CLIENT_ID: "overleaf"
OVERLEAF_OIDC_CLIENT_SECRET: "your-client-secret"
OVERLEAF_OIDC_REDIRECT_URI: "http://localhost/oidc/callback"
OVERLEAF_OIDC_SCOPES: "openid,profile,email"
```

**步骤 3: 提交**

```bash
git add services/web/app/src/router.mjs docker-compose.yml
git commit -m "feat: add OIDC routes and configuration"
```

---

### Task 5: 添加 Feature Flag

**目标：** 添加 OIDC 功能开关

**文件：**
- 修改: `services/web/app/src/infrastructure/Features.js`

**步骤 1: 添加 Feature Flag**

```javascript
// services/web/app/src/infrastructure/Features.js 添加
hasFeature(feature) {
  switch (feature) {
    // ... existing cases
    case 'oidc':
      return Boolean(Settings.enableOidc)
    case 'oidc-sso':
      return Boolean(Settings.enableOidc) && Boolean(Settings.oidc?.issuerUrl)
    default:
      return false
  }
}
```

**步骤 2: 提交**

```bash
git add services/web/app/src/infrastructure/Features.js
git commit -m "feat: add OIDC feature flags"
```

---

### Task 6: 编写 OIDC 部署文档

**目标：** 创建 OIDC 配置和部署指南

**文件：**
- 创建: `docs/plans/guides/oidc-deployment.md`

**步骤 1: 创建文档**

```markdown
# OIDC 配置指南

## 架构说明

OpenID Connect (OIDC) 是基于 OAuth 2.0 的身份认证协议。TeXDock 支持通过 OIDC 协议进行单点登录。

## 前置条件

- OIDC Provider (如 Keycloak, Auth0, Okta 等)
- Client ID 和 Client Secret
- Provider 的 Issuer URL

## 本地部署特殊配置

### 使用自签名证书

如果 OIDC Provider 使用自签名证书：

```yaml
# 在 docker-compose.yml 中添加
NODE_TLS_REJECT_UNAUTHORIZED: "0"
```

### 使用 HTTP 协议

本地部署通常使用 HTTP，需要确保：

1. OIDC Provider 允许 HTTP 回调
2. Redirect URI 使用 HTTP：`http://localhost/oidc/callback`
3. Client 配置允许本地开发

### 测试环境配置

对于本地测试，可以使用 Keycloak：

```yaml
OVERLEAF_OIDC_ENABLED: "true"
OVERLEAF_OIDC_ISSUER_URL: "http://localhost:8080/realms/master"
OVERLEAF_OIDC_CLIENT_ID: "overleaf"
OVERLEAF_OIDC_CLIENT_SECRET: "your-client-secret"
OVERLEAF_OIDC_REDIRECT_URI: "http://localhost/oidc/callback"
OVERLEAF_OIDC_SCOPES: "openid,profile,email"
```

## 配置步骤

### 1. 获取 OIDC Provider 信息

从你的 OIDC Provider 获取：
- **Issuer URL**：Provider 的基础 URL
- **Client ID**：应用的客户端 ID
- **Client Secret**：应用的客户端密钥
- **Scopes**：需要的权限范围

### 2. 配置 OIDC Provider

在 Provider 中注册 TeXDock 作为客户端：

| 配置项 | 值 |
|--------|-----|
| Client Name | TeXDock |
| Client Type | Confidential |
| Redirect URI | `http://your-domain/oidc/callback` |
| Scopes | openid, profile, email |
| Grant Types | authorization_code |

### 3. 修改 docker-compose.yml

```yaml
OVERLEAF_OIDC_ENABLED: "true"
OVERLEAF_OIDC_ISSUER_URL: "https://your-provider.com/realms/your-realm"
OVERLEAF_OIDC_CLIENT_ID: "your-client-id"
OVERLEAF_OIDC_CLIENT_SECRET: "your-client-secret"
OVERLEAF_OIDC_REDIRECT_URI: "http://your-domain/oidc/callback"
OVERLEAF_OIDC_SCOPES: "openid,profile,email"
```

### 4. 重启服务

```bash
docker compose down
docker compose up -d
```

### 5. 验证

1. 访问 http://localhost/login
2. 应该看到 "Login with OIDC" 选项
3. 点击后应重定向到 OIDC Provider
4. 登录成功后应重定向回 TeXDock

## 数据模型

### User.thirdPartyIdentifiers

```javascript
{
  providerId: String,      // OIDC Issuer URL
  externalUserId: String,  // OIDC Subject
  externalData: {
    email: String,
    name: String,
    claims: Object         // OIDC Claims
  }
}
```

## Claims 映射

默认 Claims 映射：

| OIDC Claim | TeXDock 字段 |
|------------|--------------|
| sub | externalUserId |
| email | email |
| name | first_name + last_name |
| preferred_username | username |

自定义映射：

```yaml
OVERLEAF_OIDC_CLAIMS_MAPPING: '{"email": "mail", "name": "cn"}'
```

## 常见问题

### 登录失败

检查：
1. Issuer URL 是否正确
2. Client ID 和 Secret 是否正确
3. Redirect URI 是否与 Provider 配置匹配
4. Provider 是否允许 HTTP（本地开发）

### 用户无法关联

检查：
1. 用户邮箱是否与 OIDC 中的邮箱匹配
2. 是否已存在同邮箱的本地账户
3. 查看应用日志中的错误信息

### Token 验证失败

检查：
1. Provider 的 JWKS 端点是否可访问
2. Token 是否过期
3. Token 的 issuer 是否匹配

## 安全注意事项

### 生产环境

1. **使用 HTTPS**：生产环境必须使用 HTTPS
2. **验证 Token**：始终验证 JWT 签名
3. **检查 Issuer**：验证 token 的 issuer 字段
4. **使用 PKCE**：启用 Proof Key for Code Exchange

### 本地开发

1. **自签名证书**：可以设置 `NODE_TLS_REJECT_UNAUTHORIZED=0`
2. **HTTP 协议**：确保 Provider 允许 HTTP 回调
3. **测试用户**：使用测试用户进行验证
```

**步骤 2: 提交**

```bash
git add docs/plans/guides/oidc-deployment.md
git commit -m "docs: add OIDC deployment guide"
```

---

## 验证清单

- [ ] SSOConfig 模型已扩展
- [ ] OIDCIdentityManager 模块已创建
- [ ] OIDC Passport Strategy 已创建
- [ ] OIDC 路由已添加
- [ ] Feature Flag 已添加
- [ ] 单元测试通过
- [ ] 部署文档已创建
