import AdminPagesController from './AdminPagesController.mjs'
import AuthorizationMiddleware from '../../../../app/src/Features/Authorization/AuthorizationMiddleware.js'

export default {
  apply(webRouter) {
    const adminOnly = AuthorizationMiddleware.ensureUserIsSiteAdmin

    // 用户管理面板
    webRouter.get('/admin/user', adminOnly, AdminPagesController.getUserList)
    webRouter.get(
      '/admin/user/:userId',
      adminOnly,
      AdminPagesController.getUserDetail
    )

    // 项目管理
    webRouter.get(
      '/admin/project',
      adminOnly,
      AdminPagesController.getProjectLookup
    )
    webRouter.get(
      '/admin/project/:projectId',
      adminOnly,
      AdminPagesController.getProjectDetail
    )
    webRouter.post(
      '/admin/project/:projectId/undelete',
      adminOnly,
      AdminPagesController.undeleteProject
    )
    webRouter.post(
      '/admin/project/:projectId/transfer',
      adminOnly,
      AdminPagesController.transferOwnership
    )
  },
}
