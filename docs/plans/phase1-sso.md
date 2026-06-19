# Phase 1: SSO/SAML 启用实施计划

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**目标：** 启用 SAML 2.0 单点登录，支持机构级和团队级 SSO

**架构：** 复用现有 `@node-saml/passport-saml` 集成，通过配置激活

**技术栈：** Passport.js, @node-saml/passport-saml, Express, MongoDB

**预计工期：** 1-2 天（配置 + 验证）

**本地部署注意：**
- 无 HTTPS：SAML 断言可能需要允许 HTTP
- 无证书：使用自签名证书或测试环境
- 站点地址：使用 `http://localhost`

---

### Task 1: 添加 SAML 环境变量到 docker-compose.yml

**目标：** 在 docker-compose.yml 中添加 SAML 配置模板

**文件：**
- 修改: `docker-compose.yml` (在 LDAP 配置之后添加)

**步骤 1: 添加 SAML 配置**

```yaml
      ## SAML SSO 配置（机构级单点登录）
      ## 需要 SAML Identity Provider (IdP) 支持
      # OVERLEAF_SAML_ENABLED: "true"
      # OVERLEAF_SAML_ENTRY_POINT: "https://idp.example.com/sso/saml"
      # OVERLEAF_SAML_ISSUER: "https://overleaf.example.com"
      # OVERLEAF_SAML_CERTIFICATE: "-----BEGIN CERTIFICATE-----\nMIID...\n-----END CERTIFICATE-----"
      # OVERLEAF_SAML_USER_ID_ATTRIBUTE: "urn:oid:0.9.2342.19200300.100.1.3"
      # OVERLEAF_SAML_USER_FIRST_NAME_ATTRIBUTE: "urn:oid:2.5.4.42"
      # OVERLEAF_SAML_USER_LAST_NAME_ATTRIBUTE: "urn:oid:2.5.4.4"
```

**步骤 2: 验证配置语法**

Run: `docker compose config --quiet`
Expected: 无错误输出

**步骤 3: 提交**

```bash
git add docker-compose.yml
git commit -m "chore: add SAML SSO configuration template to docker-compose"
```

---

### Task 2: 创建 SAML 测试证书

**目标：** 生成测试用 SAML 证书对

**文件：**
- 创建: `docs/plans/guides/saml-test-certs/` (目录)

**步骤 1: 生成测试证书**

```bash
mkdir -p docs/plans/guides/saml-test-certs
cd docs/plans/guides/saml-test-certs

# 生成私钥
openssl genrsa -out saml-test.key 2048

# 生成证书
openssl req -new -x509 -key saml-test.key -out saml-test.crt -days 3650 \
  -subj "/C=CN/ST=Test/L=Test/O=TeXDock/CN=idp.test.local"
```

**步骤 2: 提交**

```bash
git add docs/plans/guides/saml-test-certs/
git commit -m "chore: add test SAML certificates for development"
```

---

### Task 3: 编写 SSO 部署文档

**目标：** 创建 SAML SSO 配置和部署指南

**文件：**
- 创建: `docs/plans/guides/sso-saml-deployment.md`

**步骤 1: 创建文档**

```markdown
# SAML SSO 配置指南

## 架构说明

TeXDock 支持两种 SSO 模式：

1. **机构级 SSO**：大学/机构级别的单点登录
2. **团队级 Group SSO**：团队/订阅级别的 SSO

两者都使用 SAML 2.0 协议。

## 前置条件

- SAML Identity Provider (IdP) 支持
- IdP 的 SSO URL、X.509 证书、属性映射

## 本地部署特殊配置

### 使用自签名证书

如果 IdP 使用自签名证书，需要配置忽略证书验证：

```yaml
# 在 docker-compose.yml 中添加
NODE_TLS_REJECT_UNAUTHORIZED: "0"
```

### 使用 HTTP 协议

本地部署通常使用 HTTP，需要确保：

1. IdP 配置允许 HTTP 回调
2. ACS URL 使用 HTTP：`http://localhost/saml/acs`
3. Entity ID 使用 HTTP：`http://localhost`

### 测试环境配置

对于本地测试，可以使用测试 IdP：

```yaml
OVERLEAF_SAML_ENABLED: "true"
OVERLEAF_SAML_ENTRY_POINT: "http://localhost:8080/sso/saml"
OVERLEAF_SAML_ISSUER: "http://localhost"
OVERLEAF_SAML_CERTIFICATE: "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----"
OVERLEAF_SAML_USER_ID_ATTRIBUTE: "uid"
OVERLEAF_SAML_USER_FIRST_NAME_ATTRIBUTE: "cn"
OVERLEAF_SAML_USER_LAST_NAME_ATTRIBUTE: "sn"
```

## 配置步骤

### 1. 获取 IdP 信息

从你的 IdP 获取以下信息：
- **SSO URL** (Entry Point)：用户登录入口
- **证书**：用于验证 SAML 断言
- **属性映射**：用户 ID、邮箱、姓名等属性

### 2. 修改 docker-compose.yml

取消注释 SAML 配置并填入 IdP 信息：

\`\`\`yaml
OVERLEAF_SAML_ENABLED: "true"
OVERLEAF_SAML_ENTRY_POINT: "https://your-idp.com/sso/saml"
OVERLEAF_SAML_ISSUER: "https://your-overleaf.com"
OVERLEAF_SAML_CERTIFICATE: "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----"
OVERLEAF_SAML_USER_ID_ATTRIBUTE: "urn:oid:0.9.2342.19200300.100.1.3"
OVERLEAF_SAML_USER_FIRST_NAME_ATTRIBUTE: "urn:oid:2.5.4.42"
OVERLEAF_SAML_USER_LAST_NAME_ATTRIBUTE: "urn:oid:2.5.4.4"
\`\`\`

### 3. 配置 IdP

在 IdP 中注册 TeXDock 作为 Service Provider (SP)：
- **ACS URL**：`https://your-overleaf.com/saml/acs`
- **Entity ID**：`https://your-overleaf.com`
- **ACS Binding**：HTTP-POST

### 4. 重启服务

\`\`\`bash
docker compose down
docker compose up -d
\`\`\`

### 5. 验证

1. 访问 http://localhost/login
2. 应该看到 "Login with SSO" 选项
3. 点击后应重定向到 IdP 登录页面
4. 登录成功后应重定向回 TeXDock

## 数据模型

### SSOConfig 集合

\`\`\`javascript
{
  entryPoint: String,        // IdP SSO URL
  certificates: [String],    // X.509 证书
  userIdAttribute: String,   // 用户 ID 属性映射
  userFirstNameAttribute: String,
  userLastNameAttribute: String,
  validated: Boolean,        // 配置是否已验证
  enabled: Boolean           // 是否启用
}
\`\`\`

### User.samlIdentifiers

\`\`\`javascript
{
  externalUserId: String,    // IdP 中的用户 ID
  providerId: String,        // SSO 提供者 ID
  hasEntitlement: Boolean,   // 是否有 entitlement
  userIdAttribute: String    // 使用的属性映射
}
\`\`\`

## 常见问题

### 登录失败

检查：
1. IdP 证书是否正确
2. Entry Point URL 是否可访问
3. 属性映射是否正确
4. 用户在 IdP 中是否存在

### 用户无法关联

检查：
1. 用户邮箱是否与 IdP 中的邮箱匹配
2. 是否已存在同邮箱的本地账户
3. 查看 samlLogs 集合中的错误日志

## 审计日志

SAML 认证事件记录在 `samlLogs` 集合中：

\`\`\`javascript
{
  providerId: String,
  sessionId: String,
  userId: String,
  path: String,
  samlAssertion: String,
  jsonData: String,
  createdAt: Date
}
\`\`\`

查询最近的 SAML 日志：

\`\`\`javascript
db.samlLogs.find().sort({createdAt: -1}).limit(10)
\`\`\`
```

**步骤 2: 提交**

```bash
git add docs/plans/guides/sso-saml-deployment.md
git commit -m "docs: add SAML SSO deployment guide"
```

---

## 验证清单

- [ ] docker-compose.yml 包含 SAML 配置模板
- [ ] 测试证书已生成
- [ ] 部署文档完整且准确
- [ ] 配置语法验证通过
