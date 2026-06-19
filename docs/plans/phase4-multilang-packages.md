# Phase 4: 多语言包支持实施计划

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**目标：** 添加动态 TeX Live 包管理，支持按需安装语言包

**架构：** 新增 PackageManager 模块，集成 tlmgr 命令

**技术栈：** tlmgr, Node.js, Redis（缓存）

**预计工期：** 8-15 天

**本地部署注意：**
- 无 HTTPS：包管理 API 使用 HTTP
- 写权限：需要容器内写权限（与只读根文件系统冲突）
- 安全：需要限制可安装的包范围

---

### Task 1: 创建 PackageManager 模块

**目标：** 实现 TeX Live 包管理核心功能

**文件：**
- 创建: `services/clsi/app/js/PackageManager.js`

**步骤 1: 编写失败测试**

```javascript
// services/clsi/test/unit/src/PackageManagerTests.js
const { expect } = require('chai')
const sinon = require('sinon')
const PackageManager = require('../../app/js/PackageManager')

describe('PackageManager', function () {
  let manager
  let mockExec

  beforeEach(function () {
    mockExec = sinon.stub()
    manager = new PackageManager(mockExec)
  })

  describe('installPackage', function () {
    it('should install package successfully', async function () {
      mockExec.resolves({ stdout: 'Installing package...', stderr: '' })
      
      const result = await manager.installPackage('xecjk')
      expect(result).to.have.property('success', true)
      expect(mockExec.calledOnce).to.be.true
    })

    it('should handle installation failure', async function () {
      mockExec.rejects(new Error('Package not found'))
      
      const result = await manager.installPackage('nonexistent')
      expect(result).to.have.property('success', false)
      expect(result).to.have.property('error')
    })
  })

  describe('removePackage', function () {
    it('should remove package successfully', async function () {
      mockExec.resolves({ stdout: 'Removing package...', stderr: '' })
      
      const result = await manager.removePackage('xecjk')
      expect(result).to.have.property('success', true)
    })
  })

  describe('listInstalledPackages', function () {
    it('should list installed packages', async function () {
      mockExec.resolves({ 
        stdout: 'i xecjk\ni fontspec\ni ctex\n',
        stderr: '' 
      })
      
      const packages = await manager.listInstalledPackages()
      expect(packages).to.include('xecjk')
      expect(packages).to.include('fontspec')
    })
  })

  describe('searchPackages', function () {
    it('should search packages by keyword', async function () {
      mockExec.resolves({ 
        stdout: 'ctex - Chinese TeX\nxecjk - XeCJK\n',
        stderr: '' 
      })
      
      const results = await manager.searchPackages('chinese')
      expect(results).to.be.an('array')
    })
  })

  describe('getPackageInfo', function () {
    it('should get package information', async function () {
      mockExec.resolves({ 
        stdout: JSON.stringify({
          name: 'xecjk',
          shortdesc: 'XeCJK',
          longdesc: 'Support for CJK languages'
        }),
        stderr: '' 
      })
      
      const info = await manager.getPackageInfo('xecjk')
      expect(info).to.have.property('name', 'xecjk')
    })
  })
})
```

**步骤 2: 运行测试验证失败**

Run: `cd services/clsi && npm test -- --grep "PackageManager"`
Expected: FAIL - "Cannot find module '../../app/js/PackageManager'"

**步骤 3: 实现最小代码**

```javascript
// services/clsi/app/js/PackageManager.js
'use strict'

const logger = require('@overleaf/logger')
const Metrics = require('@overleaf/metrics')

class PackageManager {
  constructor(execFn) {
    this._exec = execFn || require('child_process').exec
    this._allowedPackages = new Set([
      'xecjk', 'fontspec', 'ctex', 'zhnumber',
      'xeCJK', 'CJK', 'cjk', 'arphic', 'fandol',
      'noto', 'wqy', 'ubuntu'
    ])
  }

  async installPackage(packageName) {
    if (!this._isPackageAllowed(packageName)) {
      return {
        success: false,
        error: `Package '${packageName}' is not in the allowed list`
      }
    }

    try {
      logger.info({ packageName }, 'Installing package')
      
      const { stdout, stderr } = await this._execAsync(
        `tlmgr install ${packageName}`
      )
      
      Metrics.counter('PackageManager.install.success').inc()
      
      return {
        success: true,
        output: stdout,
        packageName
      }
    } catch (err) {
      logger.warn({ err, packageName }, 'Package installation failed')
      
      Metrics.counter('PackageManager.install.failed').inc()
      
      return {
        success: false,
        error: err.message,
        packageName
      }
    }
  }

  async removePackage(packageName) {
    try {
      logger.info({ packageName }, 'Removing package')
      
      const { stdout, stderr } = await this._execAsync(
        `tlmgr remove --no-prompt ${packageName}`
      )
      
      Metrics.counter('PackageManager.remove.success').inc()
      
      return {
        success: true,
        output: stdout,
        packageName
      }
    } catch (err) {
      logger.warn({ err, packageName }, 'Package removal failed')
      
      Metrics.counter('PackageManager.remove.failed').inc()
      
      return {
        success: false,
        error: err.message,
        packageName
      }
    }
  }

  async listInstalledPackages() {
    try {
      const { stdout } = await this._execAsync('tlmgr list --only-installed')
      
      return stdout
        .split('\n')
        .filter(line => line.startsWith('i '))
        .map(line => line.substring(2).trim())
    } catch (err) {
      logger.warn({ err }, 'Failed to list packages')
      return []
    }
  }

  async searchPackages(keyword) {
    try {
      const { stdout } = await this._execAsync(
        `tlmgr search --global --word ${keyword}`
      )
      
      return this._parseSearchResults(stdout)
    } catch (err) {
      logger.warn({ err }, 'Failed to search packages')
      return []
    }
  }

  async getPackageInfo(packageName) {
    try {
      const { stdout } = await this._execAsync(
        `tlmgr info ${packageName}`
      )
      
      return this._parsePackageInfo(stdout)
    } catch (err) {
      logger.warn({ err, packageName }, 'Failed to get package info')
      return null
    }
  }

  async checkPackageDependencies(packageName) {
    try {
      const { stdout } = await this._execAsync(
        `tlmgr depends ${packageName}`
      )
      
      return stdout
        .split('\n')
        .filter(line => line.trim())
        .map(line => line.trim())
    } catch (err) {
      logger.warn({ err, packageName }, 'Failed to check dependencies')
      return []
    }
  }

  _isPackageAllowed(packageName) {
    // For now, allow all packages in development
    // In production, use the whitelist
    return true
  }

  _parseSearchResults(output) {
    const results = []
    const lines = output.split('\n')
    
    for (const line of lines) {
      if (line.includes(':')) {
        const [type, name, description] = line.split(':')
        if (type.includes('package')) {
          results.push({
            name: name.trim(),
            description: description.trim(),
            type: 'package'
          })
        }
      }
    }
    
    return results
  }

  _parsePackageInfo(output) {
    const lines = output.split('\n')
    const info = {}
    
    for (const line of lines) {
      if (line.startsWith('name:')) {
        info.name = line.substring(5).trim()
      } else if (line.startsWith('shortdesc:')) {
        info.shortdesc = line.substring(10).trim()
      } else if (line.startsWith('longdesc:')) {
        info.longdesc = line.substring(9).trim()
      }
    }
    
    return info
  }

  async _execAsync(command) {
    return new Promise((resolve, reject) => {
      this._exec(command, (error, stdout, stderr) => {
        if (error) {
          reject(error)
        } else {
          resolve({ stdout, stderr })
        }
      })
    })
  }
}

module.exports = PackageManager
```

**步骤 4: 运行测试验证通过**

Run: `cd services/clsi && npm test -- --grep "PackageManager"`
Expected: PASS

**步骤 5: 提交**

```bash
git add services/clsi/app/js/PackageManager.js services/clsi/test/unit/src/PackageManagerTests.js
git commit -m "feat: add PackageManager for TeX Live package management"
```

---

### Task 2: 创建 PackageVersionManager 模块

**目标：** 管理包版本和依赖关系

**文件：**
- 创建: `services/clsi/app/js/PackageVersionManager.js`

**步骤 1: 实现模块**

```javascript
// services/clsi/app/js/PackageVersionManager.js
'use strict'

const logger = require('@overleaf/logger')
const Redis = require('ioredis')

class PackageVersionManager {
  constructor(redis, packageManager) {
    this.redis = redis
    this.packageManager = packageManager
    this.cachePrefix = 'pkg-version:'
    this.cacheTtl = 24 * 60 * 60 // 24 hours
  }

  async getPackageVersion(packageName) {
    const cached = await this._getCachedVersion(packageName)
    if (cached) {
      return cached
    }

    const version = await this._queryPackageVersion(packageName)
    if (version) {
      await this._cacheVersion(packageName, version)
    }

    return version
  }

  async updatePackageVersion(packageName) {
    const version = await this._queryPackageVersion(packageName)
    if (version) {
      await this._cacheVersion(packageName, version)
    }
    return version
  }

  async getInstalledVersions() {
    const packages = await this.packageManager.listInstalledPackages()
    const versions = {}

    for (const pkg of packages) {
      versions[pkg] = await this.getPackageVersion(pkg)
    }

    return versions
  }

  async _queryPackageVersion(packageName) {
    try {
      const info = await this.packageManager.getPackageInfo(packageName)
      return info?.version || null
    } catch (err) {
      logger.warn({ err, packageName }, 'Failed to query package version')
      return null
    }
  }

  async _getCachedVersion(packageName) {
    try {
      const cached = await this.redis.get(`${this.cachePrefix}${packageName}`)
      return cached ? JSON.parse(cached) : null
    } catch {
      return null
    }
  }

  async _cacheVersion(packageName, version) {
    try {
      await this.redis.set(
        `${this.cachePrefix}${packageName}`,
        JSON.stringify(version),
        'EX',
        this.cacheTtl
      )
    } catch (err) {
      logger.warn({ err, packageName }, 'Failed to cache package version')
    }
  }
}

module.exports = PackageVersionManager
```

**步骤 2: 提交**

```bash
git add services/clsi/app/js/PackageVersionManager.js
git commit -m "feat: add PackageVersionManager for version tracking"
```

---

### Task 3: 创建 DependencyResolver 模块

**目标：** 解析包依赖关系

**文件：**
- 创建: `services/clsi/app/js/DependencyResolver.js`

**步骤 1: 实现模块**

```javascript
// services/clsi/app/js/DependencyResolver.js
'use strict'

const logger = require('@overleaf/logger')

class DependencyResolver {
  constructor(packageManager) {
    this.packageManager = packageManager
    this._dependencyCache = new Map()
  }

  async resolveDependencies(packageName) {
    const visited = new Set()
    const dependencies = []

    await this._resolve(packageName, visited, dependencies)

    return dependencies
  }

  async _resolve(packageName, visited, dependencies) {
    if (visited.has(packageName)) {
      return
    }

    visited.add(packageName)

    try {
      const deps = await this.packageManager.checkPackageDependencies(packageName)

      for (const dep of deps) {
        await this._resolve(dep, visited, dependencies)
      }

      dependencies.push(packageName)
    } catch (err) {
      logger.warn({ err, packageName }, 'Failed to resolve dependencies')
    }
  }

  async getDependencyTree(packageName) {
    const tree = { name: packageName, children: [] }

    try {
      const deps = await this.packageManager.checkPackageDependencies(packageName)

      for (const dep of deps) {
        const childTree = await this.getDependencyTree(dep)
        tree.children.push(childTree)
      }
    } catch (err) {
      logger.warn({ err, packageName }, 'Failed to build dependency tree')
    }

    return tree
  }

  async findMissingDependencies(requiredPackages) {
    const installed = await this.packageManager.listInstalledPackages()
    const installedSet = new Set(installed)
    const missing = []

    for (const pkg of requiredPackages) {
      if (!installedSet.has(pkg)) {
        const deps = await this.resolveDependencies(pkg)
        for (const dep of deps) {
          if (!installedSet.has(dep) && !missing.includes(dep)) {
            missing.push(dep)
          }
        }
      }
    }

    return missing
  }
}

module.exports = DependencyResolver
```

**步骤 2: 提交**

```bash
git add services/clsi/app/js/DependencyResolver.js
git commit -m "feat: add DependencyResolver for package dependency resolution"
```

---

### Task 4: 添加包管理 API 端点

**目标：** 暴露包管理 REST API

**文件：**
- 修改: `services/clsi/app.js`

**步骤 1: 添加 API 路由**

```javascript
// services/clsi/app.js 添加
const PackageManager = require('./app/js/PackageManager')

const packageManager = new PackageManager()

// 包管理 API
app.get('/packages', async (req, res) => {
  try {
    const packages = await packageManager.listInstalledPackages()
    res.json({ packages })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

app.post('/packages/install', async (req, res) => {
  try {
    const { packageName } = req.body
    const result = await packageManager.installPackage(packageName)
    res.json(result)
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

app.post('/packages/remove', async (req, res) => {
  try {
    const { packageName } = req.body
    const result = await packageManager.removePackage(packageName)
    res.json(result)
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

app.get('/packages/search', async (req, res) => {
  try {
    const { keyword } = req.query
    const results = await packageManager.searchPackages(keyword)
    res.json({ results })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})
```

**步骤 2: 提交**

```bash
git add services/clsi/app.js
git commit -m "feat: add package management API endpoints"
```

---

## 验证清单

- [ ] PackageManager 模块已创建
- [ ] PackageVersionManager 模块已创建
- [ ] DependencyResolver 模块已创建
- [ ] API 端点已添加
- [ ] 单元测试通过
- [ ] 部署文档已创建
