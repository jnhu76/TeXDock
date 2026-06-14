// @ts-check

const ChatApiHandler = require('./ChatApiHandler')
const SessionManager = require('../Authentication/SessionManager')
const UserInfoManager = require('../User/UserInfoManager')
const UserInfoController = require('../User/UserInfoController')
const EditorRealTimeController = require('../Editor/EditorRealTimeController')
const DocstoreManager = require('../Docstore/DocstoreManager')
const ProjectGetter = require('../Project/ProjectGetter')

function sendComment(req, res, next) {
  const { project_id: projectId, thread_id: threadId } = req.params
  const { content } = req.body
  if (typeof content !== 'string' || content.trim() === '') {
    return res.status(400).json({ message: 'content must be a non-empty string' })
  }
  const userId = SessionManager.getLoggedInUserId(req.session)
  if (userId == null) {
    return next(new Error('no logged-in user'))
  }
  ChatApiHandler.sendComment(
    projectId,
    threadId,
    userId,
    content,
    (err, message) => {
      if (err) {
        return next(err)
      }
      UserInfoManager.getPersonalInfo(message.user_id, (err, user) => {
        if (err) {
          return next(err)
        }
        message.user = user
          ? UserInfoController.formatPersonalInfo(user)
          : null
        EditorRealTimeController.emitToRoom(
          projectId,
          'new-chat-message',
          message
        )
        EditorRealTimeController.emitToRoom(
          projectId,
          'new-comment',
          threadId,
          message
        )
        // Also emit new-comment-threads so review panel picks up new threads
        const threadData = {}
        threadData[threadId] = {
          messages: [message],
          resolved: false,
        }
        EditorRealTimeController.emitToRoom(
          projectId,
          'new-comment-threads',
          threadData
        )
        res.status(201).json(message)
      })
    }
  )
}

function editMessage(req, res, next) {
  const {
    project_id: projectId,
    thread_id: threadId,
    message_id: messageId,
  } = req.params
  const { content } = req.body
  if (typeof content !== 'string' || content.trim() === '') {
    return res.status(400).json({ message: 'content must be a non-empty string' })
  }
  const userId = SessionManager.getLoggedInUserId(req.session)
  if (userId == null) {
    return next(new Error('no logged-in user'))
  }
  ChatApiHandler.editMessage(
    projectId,
    threadId,
    messageId,
    userId,
    content,
    (err) => {
      if (err) {
        return next(err)
      }
      EditorRealTimeController.emitToRoom(
        projectId,
        'edit-message',
        threadId,
        messageId,
        content
      )
      res.sendStatus(204)
    }
  )
}

function deleteMessage(req, res, next) {
  const {
    project_id: projectId,
    thread_id: threadId,
    message_id: messageId,
  } = req.params
  ChatApiHandler.deleteMessage(
    projectId,
    threadId,
    messageId,
    (err) => {
      if (err) {
        return next(err)
      }
      EditorRealTimeController.emitToRoom(
        projectId,
        'delete-message',
        threadId,
        messageId
      )
      res.sendStatus(204)
    }
  )
}

function deleteUserMessage(req, res, next) {
  const {
    project_id: projectId,
    thread_id: threadId,
    message_id: messageId,
  } = req.params
  const userId = SessionManager.getLoggedInUserId(req.session)
  if (userId == null) {
    return next(new Error('no logged-in user'))
  }
  ChatApiHandler.deleteUserMessage(
    projectId,
    threadId,
    userId,
    messageId,
    (err) => {
      if (err) {
        return next(err)
      }
      EditorRealTimeController.emitToRoom(
        projectId,
        'delete-message',
        threadId,
        messageId
      )
      res.sendStatus(204)
    }
  )
}

function resolveThread(req, res, next) {
  const { project_id: projectId, thread_id: threadId } = req.params
  const userId = SessionManager.getLoggedInUserId(req.session)
  if (userId == null) {
    return next(new Error('no logged-in user'))
  }
  ChatApiHandler.resolveThread(projectId, threadId, userId, (err) => {
    if (err) {
      return next(err)
    }
    UserInfoManager.getPersonalInfo(userId, (err, user) => {
      if (err) {
        return next(err)
      }
      const resolvedBy = user
        ? UserInfoController.formatPersonalInfo(user)
        : { id: userId, email: 'unknown', first_name: 'Unknown' }
      EditorRealTimeController.emitToRoom(
        projectId,
        'resolve-thread',
        threadId,
        resolvedBy
      )
      res.sendStatus(204)
    })
  })
}

function reopenThread(req, res, next) {
  const { project_id: projectId, thread_id: threadId } = req.params
  ChatApiHandler.reopenThread(projectId, threadId, (err) => {
    if (err) {
      return next(err)
    }
    EditorRealTimeController.emitToRoom(
      projectId,
      'reopen-thread',
      threadId
    )
    res.sendStatus(204)
  })
}

function deleteThread(req, res, next) {
  const { project_id: projectId, thread_id: threadId } = req.params
  ChatApiHandler.deleteThread(projectId, threadId, (err) => {
    if (err) {
      return next(err)
    }
    EditorRealTimeController.emitToRoom(
      projectId,
      'delete-thread',
      threadId
    )
    res.sendStatus(204)
  })
}

async function getRanges(req, res, next) {
  try {
    const { project_id: projectId } = req.params
    const ranges = await DocstoreManager.promises.getAllRanges(projectId)
    res.json(
      (ranges || []).map(doc => ({
        id: doc._id.toString(),
        ranges: doc.ranges,
      }))
    )
  } catch (err) {
    next(err)
  }
}

async function getThreads(req, res, next) {
  try {
    const { project_id: projectId } = req.params
    const loggedInUserId = String(
      SessionManager.getLoggedInUserId(req.session) || ''
    )
    const threads = await ChatApiHandler.promises.getThreads(projectId)

    // Collect unique user IDs from all messages
    const userIds = new Set()
    for (const thread of Object.values(threads || {})) {
      for (const msg of thread.messages || []) {
        if (msg.user_id) userIds.add(String(msg.user_id))
      }
    }

    // Fetch user info for all unique users in parallel
    const userMap = {}
    const results = await Promise.allSettled(
      Array.from(userIds).map(async userId => {
        const user = await UserInfoManager.promises.getPersonalInfo(userId)
        return { userId, user }
      })
    )
    for (const result of results) {
      if (result.status === 'fulfilled') {
        const { userId, user } = result.value
        if (user) {
          userMap[userId] = {
            id: user._id.toString(),
            email: user.email,
            name:
              [user.first_name, user.last_name]
                .filter(Boolean)
                .join(' ') || user.email,
            avatar_text: (
              user.first_name ||
              user.email ||
              '?'
            )[0].toUpperCase(),
            hue:
              Math.abs(
                userId
                  .split('')
                  .reduce(
                    (a, c) =>
                      ((a << 5) - a + c.charCodeAt(0)) | 0,
                    0
                  )
              ) % 360,
            isSelf: userId === loggedInUserId,
          }
        }
      }
    }

    // Enrich messages with user objects
    const enrichedThreads = {}
    for (const [threadId, thread] of Object.entries(threads || {})) {
      enrichedThreads[threadId] = {
        ...thread,
        messages: (thread.messages || []).map(msg => {
          const msgUserId = String(msg.user_id)
          return {
            ...msg,
            timestamp: new Date(msg.timestamp),
            user: userMap[msgUserId] || {
              id: msgUserId,
              email: 'unknown',
              name: 'Unknown User',
              avatar_text: '?',
              hue: 0,
              isSelf: msgUserId === loggedInUserId,
            },
          }
        }),
      }
    }

    res.json(enrichedThreads)
  } catch (err) {
    next(err)
  }
}

async function getChangesUsers(req, res, next) {
  try {
    const { project_id: projectId } = req.params
    const project = await ProjectGetter.promises.getProject(projectId, {
      owner_ref: true,
    })
    if (!project) {
      return res.sendStatus(404)
    }
    const users = []
    if (project.owner_ref) {
      const owner = await UserInfoManager.promises.getPersonalInfo(project.owner_ref)
      if (owner) {
        users.push({
          id: owner._id.toString(),
          email: owner.email,
          first_name: owner.first_name,
          last_name: owner.last_name,
        })
      }
    }
    res.json(users)
  } catch (err) {
    next(err)
  }
}

module.exports = {
  sendComment,
  editMessage,
  deleteMessage,
  deleteUserMessage,
  resolveThread,
  reopenThread,
  deleteThread,
  getRanges,
  getThreads,
  getChangesUsers,
}
