# Spec: Admin Panel 功能实现

## Objective

实现 TeXDock CE 的完整管理面板，包括用户管理、项目管理、项目恢复和所有权转移功能。基于 `admin.spec.ts` 测试定义的需求，创建 `admin-panel` 模块。

## 功能清单

### 已有功能（无需实现）
- 管理面板主页 (`GET /admin`)
- 系统消息管理
- 编辑器开关
- 断开所有用户
- 用户注册 (`GET/POST /admin/register`)

### 需要实现的功能

| # | 功能 | 路由 | 测试覆盖 |
|---|------|------|---------|
| 1 | 用户管理面板 | `GET /admin/user` | ✅ admin.spec.ts |
| 2 | 用户搜索（正则） | `GET /admin/user?search=xxx` | ✅ admin.spec.ts |
| 3 | 用户详情页 | `GET /admin/user/:userId` | ✅ admin.spec.ts |
| 4 | 项目 URL 查找 | `GET /admin/project` | ✅ admin.spec.ts |
| 5 | 项目详情页 | `GET /admin/project/:projectId` | ✅ admin.spec.ts |
| 6 | 恢复已删除项目 | `POST /admin/project/:projectId/undelete` | ✅ admin.spec.ts |
| 7 | 转移项目所有权 | `POST /admin/project/:projectId/transfer` | ✅ admin.spec.ts |

## Tech Stack

- **后端**: Node.js + Express (CommonJS)
- **前端**: Pug 模板 + Bootstrap 5
- **数据库**: MongoDB (User, Project 模型)
- **授权**: `AuthorizationMiddleware.ensureUserIsSiteAdmin`

## Commands

```bash
# 重启 web 服务
docker exec sharelatex sv restart web-overleaf

# 测试
docker exec sharelatex curl -s http://127.0.0.1:3000/admin -H "Cookie: <session>"
```

## Project Structure

```text
services/web/modules/admin-panel/
├── index.mjs                              # 模块入口
├── app/
│   ├── src/
│   │   ├── AdminPagesController.mjs       # 控制器
│   │   └── AdminPagesRouter.mjs           # 路由
│   └── views/
│       ├── user-list.pug                  # 用户列表页
│       ├── user-detail.pug                # 用户详情页
│       ├── project-lookup.pug             # 项目查找页
│       └── project-detail.pug             # 项目详情页
```

## Code Style

```js
// 控制器 - ES modules + expressify
import { expressify } from '@overleaf/promise-utils'
import UserGetter from '../../Features/User/UserGetter.js'
import ProjectGetter from '../../Features/Project/ProjectGetter.js'

export default {
  getUserList: expressify(async (req, res) => {
    const { search } = req.query
    const users = await UserGetter.promises.findByEmail(search)
    res.render('admin-panel/user-list', { users })
  }),
}
```

```pug
//- 视图 - Pug + Bootstrap 5
extends ../../../../layout-marketing

block content
  .container
    h1 User Management
    //- Bootstrap card with tabs
```

## Testing Strategy

- E2E 测试: `server-ce/test/admin.spec.ts` (已有)
- 手动验证: 浏览器访问 `/admin/user`

## Boundaries

- Always: 使用 `ensureUserIsSiteAdmin` 中间件
- Always: CSRF token 在表单中
- Ask first: 修改现有路由
- Never: 暴露密码哈希

## Success Criteria

- [ ] `GET /admin/user` 显示用户列表和搜索
- [ ] `GET /admin/user/:userId` 显示 6 个标签页
- [ ] `GET /admin/project` 显示项目搜索
- [ ] `GET /admin/project/:projectId` 显示 3 个标签页
- [ ] `POST /admin/project/:projectId/undelete` 恢复项目
- [ ] `POST /admin/project/:projectId/transfer` 转移所有权
- [ ] 所有 admin.spec.ts 测试通过

## Implementation Order

1. 模块骨架 + 路由注册
2. 用户列表页 (`GET /admin/user`)
3. 用户详情页 (`GET /admin/user/:userId`)
4. 项目查找页 (`GET /admin/project`)
5. 项目详情页 (`GET /admin/project/:projectId`)
6. 项目恢复 (`POST /admin/project/:projectId/undelete`)
7. 所有权转移 (`POST /admin/project/:projectId/transfer`)
