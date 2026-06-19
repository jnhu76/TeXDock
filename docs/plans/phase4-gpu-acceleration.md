# Phase 4: GPU 加速实施计划

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**目标：** 添加 GPU 加速编译支持，提升特定编译任务性能

**架构：** 扩展 DockerRunner，集成 NVIDIA Container Toolkit

**技术栈：** Docker, NVIDIA Container Toolkit, Node.js

**预计工期：** 5-8 天

**本地部署注意：**
- 无 HTTPS：GPU 检测使用本地 API
- 硬件依赖：需要 NVIDIA GPU 和驱动

---

### Task 1: 创建 GPUDetector 模块

**目标：** 检测 GPU 可用性和配置

**文件：**
- 创建: `services/clsi/app/js/GPUDetector.js`

**步骤 1: 编写失败测试**

```javascript
// services/clsi/test/unit/src/GPUDetectorTests.js
const { expect } = require('chai')
const sinon = require('sinon')
const GPUDetector = require('../../app/js/GPUDetector')

describe('GPUDetector', function () {
  let detector

  beforeEach(function () {
    detector = new GPUDetector()
  })

  afterEach(function () {
    sinon.restore()
  })

  describe('isAvailable', function () {
    it('should return true when NVIDIA runtime is available', async function () {
      sinon.stub(detector, '_checkNvidiaRuntime').resolves(true)
      sinon.stub(detector, '_checkGpuDevices').resolves([{ id: '0', name: 'RTX 3080' }])
      
      const result = await detector.isAvailable()
      expect(result).to.be.true
    })

    it('should return false when NVIDIA runtime is not available', async function () {
      sinon.stub(detector, '_checkNvidiaRuntime').resolves(false)
      
      const result = await detector.isAvailable()
      expect(result).to.be.false
    })
  })

  describe('getGpuDevices', function () {
    it('should return list of GPU devices', async function () {
      sinon.stub(detector, '_queryGpuDevices').resolves([
        { id: '0', name: 'RTX 3080', memory: '10GB' },
        { id: '1', name: 'RTX 3080', memory: '10GB' }
      ])
      
      const devices = await detector.getGpuDevices()
      expect(devices).to.have.lengthOf(2)
      expect(devices[0]).to.have.property('id', '0')
    })
  })

  describe('getDockerGpuArgs', function () {
    it('should return Docker GPU arguments', function () {
      const args = detector.getDockerGpuArgs({ devices: ['0'] })
      expect(args).to.include('--gpus')
      expect(args).to.include('"device=0"')
    })

    it('should return all devices when no specific device selected', function () {
      const args = detector.getDockerGpuArgs({})
      expect(args).to.include('--gpus')
      expect(args).to.include('"device=all"')
    })
  })
})
```

**步骤 2: 运行测试验证失败**

Run: `cd services/clsi && npm test -- --grep "GPUDetector"`
Expected: FAIL - "Cannot find module '../../app/js/GPUDetector'"

**步骤 3: 实现最小代码**

```javascript
// services/clsi/app/js/GPUDetector.js
'use strict'

const { exec } = require('child_process')
const { promisify } = require('util')
const execAsync = promisify(exec)
const logger = require('@overleaf/logger')

class GPUDetector {
  constructor() {
    this._cachedDevices = null
    this._cachedAvailability = null
    this._cacheExpiry = 60000 // 1 minute
    this._lastCacheTime = 0
  }

  async isAvailable() {
    if (this._cachedAvailability !== null && 
        Date.now() - this._lastCacheTime < this._cacheExpiry) {
      return this._cachedAvailability
    }

    try {
      const hasRuntime = await this._checkNvidiaRuntime()
      const devices = await this._checkGpuDevices()
      
      this._cachedAvailability = hasRuntime && devices.length > 0
      this._lastCacheTime = Date.now()
      
      return this._cachedAvailability
    } catch (err) {
      logger.warn({ err }, 'GPU detection failed')
      this._cachedAvailability = false
      return false
    }
  }

  async getGpuDevices() {
    if (this._cachedDevices !== null && 
        Date.now() - this._lastCacheTime < this._cacheExpiry) {
      return this._cachedDevices
    }

    try {
      this._cachedDevices = await this._queryGpuDevices()
      this._lastCacheTime = Date.now()
      return this._cachedDevices
    } catch (err) {
      logger.warn({ err }, 'Failed to query GPU devices')
      return []
    }
  }

  getDockerGpuArgs(options = {}) {
    const { devices = [] } = options
    
    if (devices.length === 0) {
      return ['--gpus', '"device=all"']
    }
    
    const deviceList = devices.join(',')
    return ['--gpus', `"device=${deviceList}"`]
  }

  getDockerRuntimeArgs() {
    return ['--runtime=nvidia']
  }

  async _checkNvidiaRuntime() {
    try {
      const { stdout } = await execAsync('docker info --format "{{.Runtimes}}"')
      return stdout.includes('nvidia')
    } catch {
      return false
    }
  }

  async _checkGpuDevices() {
    return this._queryGpuDevices()
  }

  async _queryGpuDevices() {
    try {
      const { stdout } = await execAsync('nvidia-smi --query-gpu=index,name,memory.total --format=csv,noheader,nounits')
      
      return stdout.trim().split('\n').map(line => {
        const [id, name, memory] = line.split(', ').map(s => s.trim())
        return { id, name, memory: `${memory}MiB` }
      })
    } catch {
      return []
    }
  }

  async getGpuInfo() {
    const available = await this.isAvailable()
    const devices = await this.getGpuDevices()
    
    return {
      available,
      devices,
      runtime: available ? 'nvidia' : 'runc',
      timestamp: new Date()
    }
  }
}

module.exports = GPUDetector
```

**步骤 4: 运行测试验证通过**

Run: `cd services/clsi && npm test -- --grep "GPUDetector"`
Expected: PASS

**步骤 5: 提交**

```bash
git add services/clsi/app/js/GPUDetector.js services/clsi/test/unit/src/GPUDetectorTests.js
git commit -m "feat: add GPUDetector for GPU availability detection"
```

---

### Task 2: 扩展 DockerRunner 支持 GPU

**目标：** 修改 DockerRunner 支持 GPU 容器

**文件：**
- 修改: `services/clsi/app/js/DockerRunner.js`

**步骤 1: 修改 DockerRunner**

```javascript
// services/clsi/app/js/DockerRunner.js 添加
const GPUDetector = require('./GPUDetector')

// 在类初始化中添加
constructor() {
  // ... existing code
  this.gpuDetector = new GPUDetector()
}

// 修改 createContainer 方法
async createContainer(projectId, options = {}) {
  const dockerOptions = {
    // ... existing options
  }

  // 检查是否需要 GPU
  if (options.useGpu) {
    const gpuAvailable = await this.gpuDetector.isAvailable()
    if (gpuAvailable) {
      const gpuArgs = this.gpuDetector.getDockerGpuArgs(options.gpuDevices)
      const runtimeArgs = this.gpuDetector.getDockerRuntimeArgs()
      
      dockerOptions.HostConfig.DeviceRequests = [{
        Driver: 'nvidia',
        Count: -1, // All devices
        Capabilities: [['gpu']]
      }]
      
      logger.info({ projectId, gpuDevices: options.gpuDevices }, 'Using GPU acceleration')
    } else {
      logger.warn({ projectId }, 'GPU requested but not available, falling back to CPU')
    }
  }

  return dockerOptions
}
```

**步骤 2: 运行测试验证通过**

Run: `cd services/clsi && npm test -- --grep "DockerRunner"`
Expected: PASS

**步骤 3: 提交**

```bash
git add services/clsi/app/js/DockerRunner.js
git commit -m "feat: extend DockerRunner to support GPU acceleration"
```

---

### Task 3: 添加 GPU 配置到设置

**目标：** 添加 GPU 相关配置选项

**文件：**
- 修改: `services/clsi/config/settings.defaults.js`

**步骤 1: 添加 GPU 配置**

```javascript
// services/clsi/config/settings.defaults.js 添加
gpu: {
  enabled: process.env.GPU_ENABLED === 'true',
  devices: process.env.GPU_DEVICES ? process.env.GPU_DEVICES.split(',') : [],
  runtime: process.env.GPU_RUNTIME || 'nvidia'
}
```

**步骤 2: 添加环境变量到 docker-compose.yml**

```yaml
  sharelatex:
    environment:
      # GPU 加速配置
      GPU_ENABLED: "false"
      # GPU_DEVICES: "0,1"  # 指定 GPU 设备
      # GPU_RUNTIME: "nvidia"
```

**步骤 3: 提交**

```bash
git add services/clsi/config/settings.defaults.js docker-compose.yml
git commit -m "feat: add GPU configuration options"
```

---

### Task 4: 编写 GPU 加速部署文档

**目标：** 创建 GPU 加速配置和部署指南

**文件：**
- 创建: `docs/plans/guides/gpu-acceleration-deployment.md`

**步骤 1: 创建文档**

```markdown
# GPU 加速配置指南

## 架构说明

GPU 加速使用 NVIDIA Container Toolkit 在 Docker 容器中运行 GPU 计算任务。

## 前置条件

- NVIDIA GPU（支持 CUDA）
- NVIDIA 驱动已安装
- NVIDIA Container Toolkit 已安装
- Docker 已配置使用 NVIDIA 运行时

## 安装 NVIDIA Container Toolkit

### Ubuntu/Debian

\`\`\`bash
# 添加 NVIDIA 仓库
distribution=$(. /etc/os-release; echo $ID$VERSION_ID)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# 安装
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

# 配置 Docker
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
\`\`\`

### 验证安装

\`\`\`bash
# 检查 NVIDIA 运行时
docker info | grep -i runtime

# 运行测试容器
docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi
\`\`\`

## 配置 TeXDock

### 1. 启用 GPU 加速

修改 docker-compose.yml：

\`\`\`yaml
services:
  sharelatex:
    environment:
      GPU_ENABLED: "true"
      GPU_DEVICES: "0"  # 使用第一个 GPU
\`\`\`

### 2. 重启服务

\`\`\`bash
docker compose down
docker compose up -d
\`\`\`

### 3. 验证

1. 检查 CLSI 日志：`docker compose logs clsi`
2. 应该看到 "Using GPU acceleration" 日志
3. 创建一个使用 TikZ 的项目进行测试

## 使用场景

### 适合 GPU 加速的编译任务

- 使用 LuaLaTeX 的复杂图形
- 大量 TikZ/PGF 绘图
- 使用 CUDA 的科学计算文档
- 机器学习相关的 LaTeX 文档

### 不适合 GPU 加速的任务

- 简单的 pdflatex 编译
- 纯文本文档
- 小型文档

## 故障排除

### GPU 不可用

1. 检查 NVIDIA 驱动：`nvidia-smi`
2. 检查 Docker 运行时：`docker info | grep runtime`
3. 检查 TeXDock 日志：`docker compose logs clsi`

### 编译失败

1. 检查容器是否有 GPU 访问权限
2. 检查 CUDA 版本兼容性
3. 查看详细错误日志

### 性能问题

1. 监控 GPU 使用率：`nvidia-smi`
2. 检查内存使用
3. 调整编译参数
```

**步骤 2: 提交**

```bash
git add docs/plans/guides/gpu-acceleration-deployment.md
git commit -m "docs: add GPU acceleration deployment guide"
```

---

## 验证清单

- [ ] GPUDetector 模块已创建
- [ ] DockerRunner 已扩展支持 GPU
- [ ] GPU 配置选项已添加
- [ ] 单元测试通过
- [ ] 部署文档已创建
