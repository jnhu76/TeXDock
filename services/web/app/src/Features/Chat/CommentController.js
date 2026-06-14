// @ts-check

const ChatApiHandler = require('./ChatApiHandler')
const SessionManager = require('../Authentication/SessionManager')
const UserInfoManager = require('../User/UserInfoManager')
const UserInfoController = require('../User/UserInfoController')
const EditorRealTimeController = require('../Editor/EditorRealTimeController')
const logger = require('@overleaf/logger')

function sendComment(req, res, next) {
  const { project_id: projectId, thread_id: threadId } = req.params
  const { content } = req.body
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
    res.sendStatus(204)
  })
}

function reopenThread(req, res, next) {
  const { project_id: projectId, thread_id: threadId } = req.params
  ChatApiHandler.reopenThread(projectId, threadId, (err) => {
    if (err) {
      return next(err)
    }
    res.sendStatus(204)
  })
}

function deleteThread(req, res, next) {
  const { project_id: projectId, thread_id: threadId } = req.params
  ChatApiHandler.deleteThread(projectId, threadId, (err) => {
    if (err) {
      return next(err)
    }
    res.sendStatus(204)
  })
}

module.exports = {
  sendComment,
  editMessage,
  deleteMessage,
  deleteUserMessage,
  resolveThread,
  reopenThread,
  deleteThread,
}
