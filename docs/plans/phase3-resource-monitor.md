# Phase 3: 资源监控实施计划

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**目标：** 添加编译过程资源监控，提供 CPU/内存使用指标

**架构：** 新增 ResourceMonitor 模块，集成 Prometheus 指标

**技术栈：** Docker API, Prometheus, Node.js

**预计工期：** 5-10 天

**本地部署注意：**
- 无 HTTPS：监控端点使用 HTTP
- 本地网络：Prometheus 使用本地网络

---

### Task 1: 创建 ResourceMonitor 模块

**目标：** 创建资源监控核心模块

**文件：**
- 创建: `services/clsi/app/js/ResourceMonitor.js`

**步骤 1: 编写失败测试**

```javascript
// services/clsi/test/unit/src/ResourceMonitorTests.js
const { expect } = require('chai')
const sinon = require('sinon')
const ResourceMonitor = require('../../app/js/ResourceMonitor')

describe('ResourceMonitor', function () {
  let monitor

  beforeEach(function () {
    monitor = new ResourceMonitor()
  })

  afterEach(function () {
    sinon.restore()
  })

  describe('getContainerStats', function () {
    it('should return container stats', async function () {
      const stats = await monitor.getContainerStats('test-container-id')
      expect(stats).to.have.property('cpu')
      expect(stats).to.have.property('memory')
      expect(stats).to.have.property('network')
    })

    it('should handle missing container gracefully', async function () {
      const stats = await monitor.getContainerStats('nonexistent')
      expect(stats).to.be.null
    })
  })

  describe('getProcessStats', function () {
    it('should return process stats', async function () {
      const stats = await monitor.getProcessStats(12345)
      expect(stats).to.have.property('cpu')
      expect(stats).to.have.property('memory')
      expect(stats).to.have.property('threads')
    })
  })
})
```

**步骤 2: 运行测试验证失败**

Run: `cd services/clsi && npm test -- --grep "ResourceMonitor"`
Expected: FAIL - "Cannot find module '../../app/js/ResourceMonitor'"

**步骤 3: 实现最小代码**

```javascript
// services/clsi/app/js/ResourceMonitor.js
'use strict'

const logger = require('@overleaf/logger')
const Metrics = require('@overleaf/metrics')

class ResourceMonitor {
  constructor() {
    this.docker = null
    this._initDocker()
  }

  _initDocker() {
    try {
      const Docker = require('dockerode')
      this.docker = new Docker({ socketPath: '/var/run/docker.sock' })
    } catch (err) {
      logger.warn({ err }, 'Docker not available, resource monitoring disabled')
    }
  }

  async getContainerStats(containerId) {
    if (!this.docker) {
      return null
    }

    try {
      const container = this.docker.getContainer(containerId)
      const stats = await container.stats({ stream: false })
      
      return {
        cpu: this._parseCpuStats(stats),
        memory: this._parseMemoryStats(stats),
        network: this._parseNetworkStats(stats),
        timestamp: new Date()
      }
    } catch (err) {
      logger.warn({ err, containerId }, 'Failed to get container stats')
      return null
    }
  }

  async getProcessStats(pid) {
    try {
      const fs = require('fs').promises
      const status = await fs.readFile(`/proc/${pid}/status`, 'utf8')
      
      const lines = status.split('\n')
      const stats = {}
      
      for (const line of lines) {
        if (line.startsWith('VmRSS:')) {
          stats.memory = parseInt(line.split(/\s+/)[1]) * 1024 // KB to bytes
        }
        if (line.startsWith('Threads:')) {
          stats.threads = parseInt(line.split(/\s+/)[1])
        }
      }
      
      stats.cpu = await this._getCpuUsage(pid)
      stats.timestamp = new Date()
      
      return stats
    } catch (err) {
      logger.warn({ err, pid }, 'Failed to get process stats')
      return null
    }
  }

  _parseCpuStats(stats) {
    const cpuDelta = stats.cpu_stats.cpu_usage.total_usage - 
                     stats.precpu_stats.cpu_usage.total_usage
    const systemDelta = stats.cpu_stats.system_cpu_usage - 
                        stats.precpu_stats.system_cpu_usage
    const cpuCount = stats.cpu_stats.online_cpus
    
    return {
      usage: systemDelta > 0 ? (cpuDelta / systemDelta) * cpuCount * 100 : 0,
      totalUsage: stats.cpu_stats.cpu_usage.total_usage,
      systemUsage: stats.cpu_stats.system_cpu_usage
    }
  }

  _parseMemoryStats(stats) {
    return {
      usage: stats.memory_stats.usage || 0,
      limit: stats.memory_stats.limit || 0,
      percentage: stats.memory_stats.limit ? 
        (stats.memory_stats.usage / stats.memory_stats.limit) * 100 : 0
    }
  }

  _parseNetworkStats(stats) {
    const networks = stats.networks || {}
    let rxBytes = 0
    let txBytes = 0
    
    for (const [iface, data] of Object.entries(networks)) {
      rxBytes += data.rx_bytes || 0
      txBytes += data.tx_bytes || 0
    }
    
    return { rxBytes, txBytes }
  }

  async _getCpuUsage(pid) {
    // Simplified CPU usage calculation
    try {
      const fs = require('fs').promises
      const stat = await fs.readFile(`/proc/${pid}/stat`, 'utf8')
      const fields = stat.split(' ')
      
      const utime = parseInt(fields[13])
      const stime = parseInt(fields[14])
      const startTime = parseInt(fields[21])
      const uptime = await this._getUptime()
      const ticks = 100 // sysconf(_SC_CLK_TCK)
      
      const totalTicks = utime + stime
      const secondsSinceStart = uptime - (startTime / ticks)
      
      return secondsSinceStart > 0 ? 
        (totalTicks / ticks) / secondsSinceStart * 100 : 0
    } catch {
      return 0
    }
  }

  async _getUptime() {
    const fs = require('fs').promises
    const uptime = await fs.readFile('/proc/uptime', 'utf8')
    return parseFloat(uptime.split(' ')[0])
  }

  recordMetrics(containerId, stats) {
    if (!stats) return

    Metrics.gauge('clsi.container.cpu.usage', stats.cpu.usage, {
      container_id: containerId
    })
    
    Metrics.gauge('clsi.container.memory.usage', stats.memory.usage, {
      container_id: containerId
    })
    
    Metrics.gauge('clsi.container.memory.percentage', stats.memory.percentage, {
      container_id: containerId
    })
    
    Metrics.gauge('clsi.container.network.rx_bytes', stats.network.rxBytes, {
      container_id: containerId
    })
    
    Metrics.gauge('clsi.container.network.tx_bytes', stats.network.txBytes, {
      container_id: containerId
    })
  }
}

module.exports = ResourceMonitor
```

**步骤 4: 运行测试验证通过**

Run: `cd services/clsi && npm test -- --grep "ResourceMonitor"`
Expected: PASS

**步骤 5: 提交**

```bash
git add services/clsi/app/js/ResourceMonitor.js services/clsi/test/unit/src/ResourceMonitorTests.js
git commit -m "feat: add ResourceMonitor module for compile process monitoring"
```

---

### Task 2: 集成 ResourceMonitor 到 CompileManager

**目标：** 在编译过程中收集资源使用指标

**文件：**
- 修改: `services/clsi/app/js/CompileManager.js`

**步骤 1: 编写失败测试**

```javascript
// 在现有 CompileManagerTests.js 中添加
describe('resource monitoring', function () {
  it('should record resource metrics during compile', async function () {
    const resourceMonitor = {
      getContainerStats: sinon.stub().resolves({
        cpu: { usage: 50 },
        memory: { usage: 1024 * 1024, percentage: 10 },
        network: { rxBytes: 100, txBytes: 200 }
      }),
      recordMetrics: sinon.stub()
    }
    
    // ... test that metrics are recorded
  })
})
```

**步骤 2: 修改 CompileManager**

```javascript
// services/clsi/app/js/CompileManager.js 顶部添加
const ResourceMonitor = require('./ResourceMonitor')

// 在类初始化中添加
constructor() {
  // ... existing code
  this.resourceMonitor = new ResourceMonitor()
}

// 在 doCompile 方法中添加监控
async doCompile(projectId, projectName, userId, options = {}) {
  // ... existing compile logic
  
  // 编译完成后记录资源使用
  if (options.containerId) {
    const stats = await this.resourceMonitor.getContainerStats(options.containerId)
    if (stats) {
      this.resourceMonitor.recordMetrics(options.containerId, stats)
      logger.info({ projectId, stats }, 'Compile resource usage')
    }
  }
  
  // ... rest of existing code
}
```

**步骤 3: 运行测试验证通过**

Run: `cd services/clsi && npm test -- --grep "CompileManager"`
Expected: PASS

**步骤 4: 提交**

```bash
git add services/clsi/app/js/CompileManager.js
git commit -m "feat: integrate ResourceMonitor into CompileManager"
```

---

### Task 3: 添加 Prometheus 指标端点

**目标：** 暴露 Prometheus 格式的监控指标

**文件：**
- 修改: `services/clsi/app.js`

**步骤 1: 添加指标端点**

```javascript
// services/clsi/app.js 添加
app.get('/metrics', async (req, res) => {
  try {
    const metrics = await Metrics.getMetrics()
    res.set('Content-Type', 'text/plain')
    res.send(metrics)
  } catch (err) {
    res.status(500).send('Error getting metrics')
  }
})
```

**步骤 2: 提交**

```bash
git add services/clsi/app.js
git commit -m "feat: add Prometheus metrics endpoint to CLSI"
```

---

## 验证清单

- [ ] ResourceMonitor 模块已创建
- [ ] 单元测试通过
- [ ] 集成到 CompileManager
- [ ] Prometheus 指标端点可用
- [ ] 部署文档已创建
