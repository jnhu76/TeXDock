# Phase 1: LDAP 启用实施计划

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**目标：** 启用 LDAP 外部认证，允许用户通过 LDAP 服务器登录

**架构：** 复用现有 `passport-ldapauth` 集成，仅需配置环境变量

**技术栈：** Passport.js, passport-ldapauth, Express

**预计工期：** 1 天（配置 + 文档）

---

### Task 1: 添加 LDAP 环境变量到 docker-compose.yml

**目标：** 在 docker-compose.yml 中添加 LDAP 配置模板

**文件：**
- 修改: `docker-compose.yml:112-121`

**步骤 1: 取消注释 LDAP 配置**

```yaml
      ## LDAP 登录配置（需要配合 LDAP 服务器使用）
      OVERLEAF_LDAP_URL: 'ldap://ldap:389'
      OVERLEAF_LDAP_SEARCH_BASE: 'ou=people,dc=example,dc=com'
      OVERLEAF_LDAP_SEARCH_FILTER: '(uid={{username}})'
      OVERLEAF_LDAP_BIND_DN: 'cn=admin,dc=example,dc=com'
      OVERLEAF_LDAP_BIND_CREDENTIALS: 'admin_password'
      OVERLEAF_LDAP_EMAIL_ATT: 'mail'
      OVERLEAF_LDAP_NAME_ATT: 'cn'
      OVERLEAF_LDAP_LAST_NAME_ATT: 'sn'
      OVERLEAF_LDAP_UPDATE_USER_DETAILS_ON_LOGIN: 'true'
```

**步骤 2: 验证配置语法**

Run: `docker compose config --quiet`
Expected: 无错误输出

**步骤 3: 提交**

```bash
git add docker-compose.yml
git commit -m "chore: add LDAP configuration template to docker-compose"
```

---

### Task 2: 编写 LDAP 部署文档

**目标：** 创建 LDAP 配置和部署指南

**文件：**
- 创建: `docs/plans/guides/ldap-deployment.md`

**步骤 1: 创建文档**

```markdown
# LDAP 配置指南

## 前置条件

- LDAP 服务器（OpenLDAP, Active Directory 等）
- 用户在 LDAP 中具有 `uid`, `mail`, `cn`, `sn` 属性

## 配置步骤

### 1. 修改 docker-compose.yml

取消注释 LDAP 相关环境变量，并修改为你的 LDAP 服务器信息：

\`\`\`yaml
OVERLEAF_LDAP_URL: 'ldap://your-ldap-server:389'
OVERLEAF_LDAP_SEARCH_BASE: 'ou=people,dc=your-domain,dc=com'
OVERLEAF_LDAP_SEARCH_FILTER: '(uid={{username}})'
OVERLEAF_LDAP_BIND_DN: 'cn=admin,dc=your-domain,dc=com'
OVERLEAF_LDAP_BIND_CREDENTIALS: 'your-admin-password'
\`\`\`

### 2. 重启服务

\`\`\`bash
docker compose down
docker compose up -d
\`\`\`

### 3. 验证

访问 http://localhost/login，应该看到 "Login with LDAP" 选项。

## 环境变量说明

| 变量 | 必填 | 说明 |
|------|------|------|
| `OVERLEAF_LDAP_URL` | 是 | LDAP 服务器 URL |
| `OVERLEAF_LDAP_SEARCH_BASE` | 是 | 搜索基础 DN |
| `OVERLEAF_LDAP_SEARCH_FILTER` | 是 | 搜索过滤器，`{{username}}` 会被替换 |
| `OVERLEAF_LDAP_BIND_DN` | 是 | 绑定 DN（用于搜索） |
| `OVERLEAF_LDAP_BIND_CREDENTIALS` | 是 | 绑定密码 |
| `OVERLEAF_LDAP_EMAIL_ATT` | 否 | 邮箱属性名，默认 `mail` |
| `OVERLEAF_LDAP_NAME_ATT` | 否 | 名字属性名，默认 `cn` |
| `OVERLEAF_LDAP_LAST_NAME_ATT` | 否 | 姓氏属性名，默认 `sn` |
| `OVERLEAF_LDAP_UPDATE_USER_DETAILS_ON_LOGIN` | 否 | 登录时更新用户信息，默认 `false` |

## 常见问题

### 连接失败

检查：
1. LDAP 服务器是否可达
2. 端口是否正确（默认 389，LDAPS 为 636）
3. 绑定 DN 和密码是否正确

### 用户搜索不到

检查：
1. `SEARCH_BASE` 是否正确
2. `SEARCH_FILTER` 是否匹配用户属性
3. 绑定用户是否有搜索权限
```

**步骤 2: 提交**

```bash
git add docs/plans/guides/ldap-deployment.md
git commit -m "docs: add LDAP deployment guide"
```

---

## 验证清单

- [ ] docker-compose.yml 包含 LDAP 配置模板
- [ ] 部署文档完整且准确
- [ ] 配置语法验证通过
