import path from 'path'
import { fileURLToPath } from 'url'
import { expressify } from '@overleaf/promise-utils'
import UserGetter from '../../../../app/src/Features/User/UserGetter.js'
import ProjectGetter from '../../../../app/src/Features/Project/ProjectGetter.js'
import ProjectDeleter from '../../../../app/src/Features/Project/ProjectDeleter.js'
import { UserAuditLogEntry } from '../../../../app/src/models/UserAuditLogEntry.js'
import { ProjectAuditLogEntry } from '../../../../app/src/models/ProjectAuditLogEntry.js'
import SessionManager from '../../../../app/src/Features/Authentication/SessionManager.js'
import OwnershipTransferHandler from '../../../../app/src/Features/Collaborators/OwnershipTransferHandler.js'
import mongodb from '../../../../app/src/infrastructure/mongodb.js'

const { db } = mongodb

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

function viewPath(name) {
  return path.resolve(__dirname, `../views/admin-panel/${name}`)
}

const USER_FIELDS = {
  email: 1,
  signUpDate: 1,
  isAdmin: 1,
  lastLoggedIn: 1,
  lastLoginIp: 1,
  loginCount: 1,
  holdingAccount: 1,
}

export default {
  getUserList: expressify(async (req, res) => {
    const { search, searchType } = req.query
    let users = []

    if (search) {
      if (searchType === 'regexp') {
        try {
          const regex = new RegExp(search, 'i')
          users = await db.users
            .find({ email: { $regex: regex } }, { projection: USER_FIELDS })
            .limit(50)
            .toArray()
        } catch {
          users = []
        }
      } else {
        const user = await UserGetter.promises.getUserByAnyEmail(
          search,
          USER_FIELDS
        )
        if (user) users = [user]

        if (users.length === 0) {
          try {
            const userById = await UserGetter.promises.getUser(
              search,
              USER_FIELDS
            )
            if (userById) users = [userById]
          } catch {
            // invalid id
          }
        }
      }
    }

    res.render(viewPath('user-list'), {
      users,
      search: search || '',
      searchType: searchType || '',
    })
  }),

  getUserDetail: expressify(async (req, res) => {
    const { userId } = req.params
    const user = await UserGetter.promises.getUser(userId)
    if (!user) {
      return res.status(404).render(viewPath('not-found'), { type: 'User' })
    }

    const projectsResult = await ProjectGetter.promises.findAllUsersProjects(
      userId,
      { name: 1, lastUpdated: 1 }
    )
    const projects = [
      ...projectsResult.owned,
      ...projectsResult.readAndWrite,
      ...projectsResult.readOnly,
      ...projectsResult.tokenReadAndWrite,
      ...projectsResult.tokenReadOnly,
      ...projectsResult.review,
    ]

    const deletedProjects = await db.projects
      .find({
        'overleaf.history.projectId': { $exists: true },
        deleted: { $exists: true },
        owner_ref: user._id,
      })
      .toArray()

    const auditLog = await UserAuditLogEntry.find({ userId })
      .sort({ timestamp: -1 })
      .limit(100)
      .lean()

    res.render(viewPath('user-detail'), {
      user,
      projects,
      deletedProjects,
      auditLog,
    })
  }),

  getProjectLookup: expressify(async (req, res) => {
    const { search } = req.query
    let projects = []

    if (search) {
      try {
        const project = await ProjectGetter.promises.getProject(search, {
          name: 1,
          owner_ref: 1,
          createdAt: 1,
          lastUpdated: 1,
        })
        if (project) projects = [project]
      } catch {
        // invalid id
      }

      if (projects.length === 0) {
        const nameResults = await db.projects
          .find(
            { name: { $regex: search, $options: 'i' } },
            {
              projection: {
                name: 1,
                owner_ref: 1,
                createdAt: 1,
                lastUpdated: 1,
              },
            }
          )
          .limit(50)
          .toArray()
        projects = nameResults
      }
    }

    res.render(viewPath('project-lookup'), {
      projects,
      search: search || '',
    })
  }),

  getProjectDetail: expressify(async (req, res) => {
    const { projectId } = req.params
    const project = await ProjectGetter.promises.getProject(projectId)
    if (!project) {
      return res
        .status(404)
        .render(viewPath('not-found'), { type: 'Project' })
    }

    const owner = await UserGetter.promises.getUser(project.owner_ref, {
      email: 1,
    })

    const auditLog = await ProjectAuditLogEntry.find({ projectId })
      .sort({ timestamp: -1 })
      .limit(100)
      .lean()

    res.render(viewPath('project-detail'), {
      project,
      owner,
      auditLog,
    })
  }),

  undeleteProject: expressify(async (req, res) => {
    const { projectId } = req.params
    await ProjectDeleter.promises.undeleteProject(projectId)
    res.redirect(`/admin/project/${projectId}`)
  }),

  transferOwnership: expressify(async (req, res) => {
    const { projectId } = req.params
    const { targetUserId } = req.body

    let targetUser = null
    try {
      targetUser = await UserGetter.promises.getUserByAnyEmail(targetUserId)
    } catch {
      // try by id
    }
    if (!targetUser) {
      try {
        targetUser = await UserGetter.promises.getUser(targetUserId)
      } catch {
        // user not found
      }
    }

    if (!targetUser) {
      return res.status(404).render(viewPath('not-found'), { type: 'User' })
    }

    const project = await ProjectGetter.promises.getProject(projectId)
    if (!project) {
      return res
        .status(404)
        .render(viewPath('not-found'), { type: 'Project' })
    }

    const adminUserId = SessionManager.getLoggedInUserId(req.session)
    const ipAddress = req.ip
    await OwnershipTransferHandler.promises.transferOwnership(
      projectId,
      targetUser._id,
      {
        allowTransferToNonCollaborators: true,
        sessionUserId: adminUserId,
        skipEmails: true,
        ipAddress,
      }
    )

    res.redirect(`/admin/project/${projectId}`)
  }),
}
