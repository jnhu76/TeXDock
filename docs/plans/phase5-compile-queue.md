# Phase 5: 编译队列实施计划

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**目标：** 将同步编译改为异步队列，支持优先级和并发控制

**架构：** 使用 Bull 队列（已有依赖），Redis 作为 broker

**技术栈：** Bull, Redis, WebSocket, Node.js

**预计工期：** 10-20 天

**本地部署注意：**
- 无 HTTPS：WebSocket 使用 ws:// 协议
- 本地网络：Redis 使用本地网络

---

### Task 1: 创建 CompileQueue 模块

**目标：** 实现编译队列核心功能

**文件：**
- 创建: `services/web/app/src/infrastructure/CompileQueue.js`

**步骤 1: 编写失败测试**

```javascript
// services/web/test/unit/src/infrastructure/CompileQueueTests.js
const { expect } = require('chai')
const sinon = require('sinon')
const Bull = require('bull')
const CompileQueue = require('../../../../app/src/infrastructure/CompileQueue')

describe('CompileQueue', function () {
  let queue
  let mockRedis

  beforeEach(function () {
    mockRedis = {
      createClient: sinon.stub()
    }
    queue = new CompileQueue(mockRedis)
  })

  afterEach(function () {
    sinon.restore()
  })

  describe('addJob', function () {
    it('should add job to queue', async function () {
      const mockBullQueue = {
        add: sinon.stub().resolves({ id: 'job123' })
      }
      sinon.stub(queue, '_getQueue').returns(mockBullQueue)
      
      const job = await queue.addJob({
        projectId: 'proj123',
        userId: 'user123',
        compileGroup: 'standard'
      })
      
      expect(job).to.have.property('id', 'job123')
      expect(mockBullQueue.add.calledOnce).to.be.true
    })
  })

  describe('getJobStatus', function () {
    it('should return job status', async function () {
      const mockBullQueue = {
        getJob: sinon.stub().resolves({
          id: 'job123',
          data: { projectId: 'proj123' },
          progress: 50,
          status: 'active'
        })
      }
      sinon.stub(queue, '_getQueue').returns(mockBullQueue)
      
      const status = await queue.getJobStatus('job123')
      expect(status).to.have.property('id', 'job123')
      expect(status).to.have.property('progress', 50)
    })
  })

  describe('cancelJob', function () {
    it('should cancel job', async function () {
      const mockJob = {
        remove: sinon.stub().resolves()
      }
      const mockBullQueue = {
        getJob: sinon.stub().resolves(mockJob)
      }
      sinon.stub(queue, '_getQueue').returns(mockBullQueue)
      
      const result = await queue.cancelJob('job123')
      expect(result).to.be.true
      expect(mockJob.remove.calledOnce).to.be.true
    })
  })
})
```

**步骤 2: 运行测试验证失败**

Run: `cd services/web && npm test -- --grep "CompileQueue"`
Expected: FAIL - "Cannot find module '../../../../app/src/infrastructure/CompileQueue'"

**步骤 3: 实现最小代码**

```javascript
// services/web/app/src/infrastructure/CompileQueue.js
'use strict'

const Bull = require('bull')
const logger = require('@overleaf/logger')
const Metrics = require('@overleaf/metrics')

class CompileQueue {
  constructor(redisConfig) {
    this.redisConfig = redisConfig
    this.queues = new Map()
  }

  _getQueue(compileGroup) {
    if (!this.queues.has(compileGroup)) {
      const queue = new Bull(`compile-${compileGroup}`, {
        redis: this.redisConfig,
        defaultJobOptions: {
          removeOnComplete: 100,
          removeOnFail: 50,
          attempts: 3,
          backoff: {
            type: 'exponential',
            delay: 2000
          }
        }
      })

      queue.on('error', (err) => {
        logger.error({ err, compileGroup }, 'Queue error')
      })

      queue.on('completed', (job, result) => {
        Metrics.counter('compile-queue.completed', { compileGroup }).inc()
        logger.info({ jobId: job.id, compileGroup }, 'Compile job completed')
      })

      queue.on('failed', (job, err) => {
        Metrics.counter('compile-queue.failed', { compileGroup }).inc()
        logger.warn({ jobId: job.id, compileGroup, err }, 'Compile job failed')
      })

      this.queues.set(compileGroup, queue)
    }

    return this.queues.get(compileGroup)
  }

  async addJob(jobData) {
    const { compileGroup = 'standard', priority = 0 } = jobData
    const queue = this._getQueue(compileGroup)

    const job = await queue.add(jobData, {
      priority,
      jobId: `compile:${jobData.projectId}:${Date.now()}`
    })

    Metrics.counter('compile-queue.added', { compileGroup }).inc()

    return {
      id: job.id,
      compileGroup,
      status: 'waiting'
    }
  }

  async getJobStatus(jobId) {
    for (const [compileGroup, queue] of this.queues) {
      const job = await queue.getJob(jobId)
      if (job) {
        return {
          id: job.id,
          data: job.data,
          progress: job.progress(),
          status: await job.getState(),
          timestamp: job.timestamp,
          attemptsMade: job.attemptsMade
        }
      }
    }

    return null
  }

  async cancelJob(jobId) {
    for (const [compileGroup, queue] of this.queues) {
      const job = await queue.getJob(jobId)
      if (job) {
        await job.remove()
        Metrics.counter('compile-queue.cancelled', { compileGroup }).inc()
        return true
      }
    }

    return false
  }

  async getQueueStats(compileGroup) {
    const queue = this._getQueue(compileGroup)
    const [waiting, active, completed, failed, delayed] = await Promise.all([
      queue.getWaitingCount(),
      queue.getActiveCount(),
      queue.getCompletedCount(),
      queue.getFailedCount(),
      queue.getDelayedCount()
    ])

    return {
      compileGroup,
      waiting,
      active,
      completed,
      failed,
      delayed
    }
  }

  async cleanQueue(compileGroup, grace = 5000) {
    const queue = this._getQueue(compileGroup)
    await queue.clean(grace, 'completed')
    await queue.clean(grace, 'failed')
  }

  async closeAll() {
    for (const [compileGroup, queue] of this.queues) {
      await queue.close()
    }
    this.queues.clear()
  }
}

module.exports = CompileQueue
```

**步骤 4: 运行测试验证通过**

Run: `cd services/web && npm test -- --grep "CompileQueue"`
Expected: PASS

**步骤 5: 提交**

```bash
git add services/web/app/src/infrastructure/CompileQueue.js services/web/test/unit/src/infrastructure/CompileQueueTests.js
git commit -m "feat: add CompileQueue for async compile job management"
```

---

### Task 2: 创建 CompileWorker 模块

**目标：** 实现队列消费者，处理编译任务

**文件：**
- 创建: `services/web/app/src/Features/Compile/CompileWorker.js`

**步骤 1: 实现模块**

```javascript
// services/web/app/src/Features/Compile/CompileWorker.js
'use strict'

const logger = require('@overleaf/logger')
const Metrics = require('@overleaf/metrics')
const ClsiManager = require('./ClsiManager')

class CompileWorker {
  constructor(compileQueue) {
    this.queue = compileQueue
    this.workers = new Map()
  }

  start(compileGroup, concurrency = 1) {
    const queue = this.queue._getQueue(compileGroup)

    const worker = queue.process(concurrency, async (job) => {
      const { projectId, userId, options } = job.data

      logger.info({ projectId, userId, compileGroup }, 'Starting compile job')

      try {
        // 更新进度
        await job.progress(10)

        // 调用 CLSI 编译
        const result = await ClsiManager.sendRequest(projectId, options)

        // 更新进度
        await job.progress(90)

        // 存储结果
        const compileResult = {
          buildId: result.buildId,
          status: result.status,
          outputFiles: result.outputFiles,
          compileGroup: result.compileGroup,
          stats: result.stats,
          timings: result.timings
        }

        // 完成
        await job.progress(100)

        Metrics.counter('compile-worker.success', { compileGroup }).inc()

        return compileResult
      } catch (err) {
        logger.error({ err, projectId, userId }, 'Compile job failed')
        Metrics.counter('compile-worker.failed', { compileGroup }).inc()
        throw err
      }
    })

    this.workers.set(compileGroup, worker)

    logger.info({ compileGroup, concurrency }, 'Compile worker started')
  }

  stop(compileGroup) {
    const worker = this.workers.get(compileGroup)
    if (worker) {
      worker.close()
      this.workers.delete(compileGroup)
      logger.info({ compileGroup }, 'Compile worker stopped')
    }
  }

  stopAll() {
    for (const [compileGroup, worker] of this.workers) {
      worker.close()
    }
    this.workers.clear()
    logger.info('All compile workers stopped')
  }

  async getWorkerStats() {
    const stats = {}

    for (const [compileGroup, worker] of this.workers) {
      stats[compileGroup] = {
        isRunning: worker.running,
        concurrency: worker.concurrency
      }
    }

    return stats
  }
}

module.exports = CompileWorker
```

**步骤 2: 提交**

```bash
git add services/web/app/src/Features/Compile/CompileWorker.js
git commit -m "feat: add CompileWorker for async compile processing"
```

---

### Task 3: 修改 CompileManager 支持队列

**目标：** 修改 CompileManager 支持同步和异步模式

**文件：**
- 修改: `services/web/app/src/Features/Compile/CompileManager.js`

**步骤 1: 修改 CompileManager**

```javascript
// services/web/app/src/Features/Compile/CompileManager.js 添加
const CompileQueue = require('../../infrastructure/CompileQueue')

// 在类初始化中添加
constructor() {
  // ... existing code
  this.compileQueue = new CompileQueue(redisConfig)
  this.useQueue = process.env.COMPILE_QUEUE_ENABLED === 'true'
}

// 修改 compile 方法
async compile(projectId, userId, options = {}) {
  // ... existing validation code

  if (this.useQueue) {
    // 异步队列模式
    const job = await this.compileQueue.addJob({
      projectId,
      userId,
      options,
      compileGroup: options.compileGroup || 'standard',
      priority: options.priority || 0
    })

    return {
      status: 'queued',
      jobId: job.id,
      message: 'Compile job queued'
    }
  } else {
    // 同步模式（现有逻辑）
    return await this._compileSync(projectId, userId, options)
  }
}

async _compileSync(projectId, userId, options) {
  // ... existing compile logic
}
```

**步骤 2: 提交**

```bash
git add services/web/app/src/Features/Compile/CompileManager.js
git commit -m "feat: integrate CompileQueue into CompileManager"
```

---

### Task 4: 添加 WebSocket 进度推送

**目标：** 实时推送编译进度到前端

**文件：**
- 修改: `services/real-time/app/js/WebSocketManager.js`

**步骤 1: 添加进度推送**

```javascript
// services/real-time/app/js/WebSocketManager.js 添加
async sendCompileProgress(projectId, userId, progress) {
  const room = `project:${projectId}:${userId}`
  this.io.to(room).emit('compile:progress', {
    projectId,
    userId,
    progress: {
      status: progress.status,
      percentage: progress.percentage,
      message: progress.message
    },
    timestamp: new Date()
  })
}
```

**步骤 2: 提交**

```bash
git add services/real-time/app/js/WebSocketManager.js
git commit -m "feat: add WebSocket compile progress broadcasting"
```

---

### Task 5: 修改前端支持异步编译

**目标：** 前端支持异步编译状态显示

**文件：**
- 修改: `services/web/frontend/js/shared/context/local-compile-context.tsx`

**步骤 1: 修改编译上下文**

```typescript
// services/web/frontend/js/shared/context/local-compile-context.tsx 添加
interface CompileQueueStatus {
  jobId: string | null
  status: 'idle' | 'queued' | 'compiling' | 'completed' | 'failed'
  progress: number
  message: string
}

// 在 context 中添加
const [queueStatus, setQueueStatus] = useState<CompileQueueStatus>({
  jobId: null,
  status: 'idle',
  progress: 0,
  message: ''
})

// 监听 WebSocket 进度
useEffect(() => {
  const socket = getSocket()
  
  socket.on('compile:progress', (data) => {
    if (data.projectId === projectId) {
      setQueueStatus({
        jobId: data.jobId,
        status: data.progress.status,
        progress: data.progress.percentage,
        message: data.progress.message
      })
    }
  })
  
  return () => {
    socket.off('compile:progress')
  }
}, [projectId])
```

**步骤 2: 提交**

```bash
git add services/web/frontend/js/shared/context/local-compile-context.tsx
git commit -m "feat: add async compile status display to frontend"
```

---

## 验证清单

- [ ] CompileQueue 模块已创建
- [ ] CompileWorker 模块已创建
- [ ] CompileManager 已修改支持队列
- [ ] WebSocket 进度推送已添加
- [ ] 前端异步编译支持已添加
- [ ] 单元测试通过
- [ ] 部署文档已创建
