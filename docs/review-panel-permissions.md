# 审阅面板路由权限模型

## 权限级别

| 级别 | 中间件 | 说明 |
|------|--------|------|
| 读取 | `ensureUserCanReadProject` | 查看项目内容 |
| 写入 | `ensureUserCanWriteProjectContent` | 编辑/删除内容（doc、file、folder、评论） |
| 管理 | `ensureUserCanAdminProject` | 管理协作者、邀请、所有权 |
| Chat | `requirePermission('chat')` | chat 功能启用时可用 |

## 审阅面板路由

### 读取端点

| 路由 | 权限 | 说明 |
|------|------|------|
| `GET /project/:id/ranges` | read + chat | 返回文档评论锚定位置 |
| `GET /project/:id/threads` | read + chat | 返回带 user 对象的评论线程 |
| `GET /project/:id/changes/users` | read | 返回项目用户信息（不需要 chat） |

### 写入端点

| 路由 | 权限 | 说明 |
|------|------|------|
| `POST /project/:id/thread/:tid/messages` | read + chat | 发送评论 |
| `POST /project/:id/thread/:tid/messages/:mid/edit` | read + chat | 编辑消息（后端验证 userId） |
| `DELETE /project/:id/thread/:tid/messages/:mid` | **write** + chat | 删除任何人的消息 |
| `DELETE /project/:id/thread/:tid/own-messages/:mid` | read + chat | 删除自己的消息 |
| `POST /project/:id/thread/:tid/resolve` | read + chat | 解决评论线程 |
| `POST /project/:id/thread/:tid/reopen` | read + chat | 重开评论线程 |
| `DELETE /project/:id/thread/:tid` | **write** + chat | 删除整个评论线程 |

## 权限设计原则

1. **读取操作** → `ensureUserCanReadProject`（任何项目成员）
2. **内容删除** → `ensureUserCanWriteProjectContent`（与删除 doc/file/folder 一致）
3. **管理操作** → `ensureUserCanAdminProject`（仅管理员/所有者）
4. **Chat 功能** → `requirePermission('chat')`（保护所有评论相关端点）

## 与其他路由的权限对比

| 操作类型 | 路由示例 | 权限 |
|---------|---------|------|
| 删除 doc/file/folder | `DELETE /Project/:id/doc/:id` | write |
| 删除评论消息 | `DELETE /thread/:id/messages/:id` | write |
| 删除评论线程 | `DELETE /thread/:id` | write |
| 管理协作者 | `PUT /Project/:id/users/:id` | admin |
| 邀请用户 | `POST /Project/:id/invite` | admin |
| 发送聊天消息 | `POST /project/:id/messages` | read + chat |

## 相关文件

- `services/web/app/src/router.mjs` — 路由定义（line 1089-1288）
- `services/web/app/src/Features/Chat/CommentController.js` — 评论控制器
- `services/web/app/src/Features/Chat/ChatApiHandler.js` — chat 服务 API
- `services/web/app/src/Features/Authorization/AuthorizationMiddleware.js` — 权限中间件
