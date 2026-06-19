# Phase 3: 编译结果缓存增强实施计划

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**目标：** 增强编译结果缓存，支持内容感知缓存和跨项目共享

**架构：** 扩展现有 OutputCacheManager，新增 CacheInvalidator 和 SharedCacheManager

**技术栈：** Node.js, Redis, 文件系统

**预计工期：** 3-5 天

---

### Task 1: 创建 CacheInvalidator 模块

**目标：** 实现缓存失效策略

**文件：**
- 创建: `services/clsi/app/js/CacheInvalidator.js`

**步骤 1: 编写失败测试**

```javascript
// services/clsi/test/unit/src/CacheInvalidatorTests.js
const { expect } = require('chai')
const sinon = require('sinon')
const CacheInvalidator = require('../../app/js/CacheInvalidator')

describe('CacheInvalidator', function () {
  let invalidator

  beforeEach(function () {
    invalidator = new CacheInvalidator()
  })

  describe('shouldInvalidate', function () {
    it('should invalidate when compiler changes', function () {
      const cacheKey = { compiler: 'pdflatex', files: 'abc123' }
      const currentKey = { compiler: 'xelatex', files: 'abc123' }
      
      expect(invalidator.shouldInvalidate(cacheKey, currentKey)).to.be.true
    })

    it('should invalidate when files change', function () {
      const cacheKey = { compiler: 'pdflatex', files: 'abc123' }
      const currentKey = { compiler: 'pdflatex', files: 'def456' }
      
      expect(invalidator.shouldInvalidate(cacheKey, currentKey)).to.be.true
    })

    it('should not invalidate when nothing changes', function () {
      const cacheKey = { compiler: 'pdflatex', files: 'abc123' }
      const currentKey = { compiler: 'pdflatex', files: 'abc123' }
      
      expect(invalidator.shouldInvalidate(cacheKey, currentKey)).to.be.false
    })
  })

  describe('generateCacheKey', function () {
    it('should generate consistent key', function () {
      const key1 = invalidator.generateCacheKey({
        compiler: 'pdflatex',
        rootDoc: 'main.tex',
        files: { 'main.tex': 'content1', 'style.sty': 'content2' }
      })
      
      const key2 = invalidator.generateCacheKey({
        compiler: 'pdflatex',
        rootDoc: 'main.tex',
        files: { 'main.tex': 'content1', 'style.sty': 'content2' }
      })
      
      expect(key1).to.equal(key2)
    })

    it('should generate different keys for different content', function () {
      const key1 = invalidator.generateCacheKey({
        compiler: 'pdflatex',
        rootDoc: 'main.tex',
        files: { 'main.tex': 'content1' }
      })
      
      const key2 = invalidator.generateCacheKey({
        compiler: 'pdflatex',
        rootDoc: 'main.tex',
        files: { 'main.tex': 'content2' }
      })
      
      expect(key1).to.not.equal(key2)
    })
  })
})
```

**步骤 2: 运行测试验证失败**

Run: `cd services/clsi && npm test -- --grep "CacheInvalidator"`
Expected: FAIL - "Cannot find module '../../app/js/CacheInvalidator'"

**步骤 3: 实现最小代码**

```javascript
// services/clsi/app/js/CacheInvalidator.js
'use strict'

const crypto = require('crypto')

class CacheInvalidator {
  constructor() {
    this.invalidationRules = [
      this._compilerChanged,
      this._filesChanged,
      this._imageNameChanged,
      this._rootDocChanged
    ]
  }

  shouldInvalidate(cacheKey, currentKey) {
    return this.invalidationRules.some(rule => rule(cacheKey, currentKey))
  }

  generateCacheKey(options) {
    const { compiler, rootDoc, files, imageName } = options
    
    // Sort files for consistent hashing
    const sortedFiles = Object.keys(files)
      .sort()
      .reduce((acc, key) => {
        acc[key] = files[key]
        return acc
      }, {})
    
    const content = JSON.stringify({
      compiler,
      rootDoc,
      imageName,
      files: sortedFiles
    })
    
    return crypto.createHash('sha256').update(content).digest('hex')
  }

  _compilerChanged(cacheKey, currentKey) {
    return cacheKey.compiler !== currentKey.compiler
  }

  _filesChanged(cacheKey, currentKey) {
    return cacheKey.filesHash !== currentKey.filesHash
  }

  _imageNameChanged(cacheKey, currentKey) {
    return cacheKey.imageName !== currentKey.imageName
  }

  _rootDocChanged(cacheKey, currentKey) {
    return cacheKey.rootDoc !== currentKey.rootDoc
  }

  extractCacheKeyFromResponse(response) {
    return {
      compiler: response.compiler,
      rootDoc: response.rootDoc,
      imageName: response.imageName,
      filesHash: this._hashFiles(response.files)
    }
  }

  _hashFiles(files) {
    if (!files) return ''
    
    const content = JSON.stringify(Object.keys(files).sort())
    return crypto.createHash('sha256').update(content).digest('hex')
  }
}

module.exports = CacheInvalidator
```

**步骤 4: 运行测试验证通过**

Run: `cd services/clsi && npm test -- --grep "CacheInvalidator"`
Expected: PASS

**步骤 5: 提交**

```bash
git add services/clsi/app/js/CacheInvalidator.js services/clsi/test/unit/src/CacheInvalidatorTests.js
git commit -m "feat: add CacheInvalidator for content-aware cache invalidation"
```

---

### Task 2: 创建 SharedCacheManager 模块

**目标：** 实现跨项目缓存共享

**文件：**
- 创建: `services/clsi/app/js/SharedCacheManager.js`

**步骤 1: 编写失败测试**

```javascript
// services/clsi/test/unit/src/SharedCacheManagerTests.js
const { expect } = require('chai')
const sinon = require('sinon')
const SharedCacheManager = require('../../app/js/SharedCacheManager')

describe('SharedCacheManager', function () {
  let manager
  let mockRedis

  beforeEach(function () {
    mockRedis = {
      get: sinon.stub(),
      set: sinon.stub(),
      del: sinon.stub(),
      keys: sinon.stub()
    }
    manager = new SharedCacheManager(mockRedis)
  })

  describe('findSharedCache', function () {
    it('should find matching cache entry', async function () {
      mockRedis.keys.resolves(['cache:hash123', 'cache:hash456'])
      mockRedis.get.resolves(JSON.stringify({
        outputPath: '/path/to/output',
        compiler: 'pdflatex'
      }))
      
      const result = await manager.findSharedCache('hash123', 'pdflatex')
      expect(result).to.deep.equal({
        outputPath: '/path/to/output',
        compiler: 'pdflatex'
      })
    })

    it('should return null when no match found', async function () {
      mockRedis.keys.resolves([])
      
      const result = await manager.findSharedCache('hash123', 'pdflatex')
      expect(result).to.be.null
    })
  })

  describe('storeSharedCache', function () {
    it('should store cache entry', async function () {
      await manager.storeSharedCache('hash123', {
        outputPath: '/path/to/output',
        compiler: 'pdflatex'
      })
      
      expect(mockRedis.set.calledOnce).to.be.true
    })
  })
})
```

**步骤 2: 运行测试验证失败**

Run: `cd services/clsi && npm test -- --grep "SharedCacheManager"`
Expected: FAIL - "Cannot find module '../../app/js/SharedCacheManager'"

**步骤 3: 实现最小代码**

```javascript
// services/clsi/app/js/SharedCacheManager.js
'use strict'

const logger = require('@overleaf/logger')

class SharedCacheManager {
  constructor(redis) {
    this.redis = redis
    this.prefix = 'shared-cache:'
    this.ttl = 7 * 24 * 60 * 60 // 7 days
  }

  async findSharedCache(filesHash, compiler) {
    try {
      const pattern = `${this.prefix}${filesHash}:*`
      const keys = await this.redis.keys(pattern)
      
      for (const key of keys) {
        const cached = await this.redis.get(key)
        if (cached) {
          const entry = JSON.parse(cached)
          if (entry.compiler === compiler) {
            return entry
          }
        }
      }
      
      return null
    } catch (err) {
      logger.warn({ err }, 'Failed to find shared cache')
      return null
    }
  }

  async storeSharedCache(filesHash, cacheEntry) {
    try {
      const key = `${this.prefix}${filesHash}:${cacheEntry.compiler}`
      await this.redis.set(key, JSON.stringify(cacheEntry), 'EX', this.ttl)
    } catch (err) {
      logger.warn({ err }, 'Failed to store shared cache')
    }
  }

  async invalidateSharedCache(filesHash) {
    try {
      const pattern = `${this.prefix}${filesHash}:*`
      const keys = await this.redis.keys(pattern)
      
      for (const key of keys) {
        await this.redis.del(key)
      }
    } catch (err) {
      logger.warn({ err }, 'Failed to invalidate shared cache')
    }
  }

  async getCacheStats() {
    try {
      const pattern = `${this.prefix}*`
      const keys = await this.redis.keys(pattern)
      
      return {
        totalEntries: keys.length,
        prefix: this.prefix
      }
    } catch (err) {
      logger.warn({ err }, 'Failed to get cache stats')
      return { totalEntries: 0, prefix: this.prefix }
    }
  }
}

module.exports = SharedCacheManager
```

**步骤 4: 运行测试验证通过**

Run: `cd services/clsi && npm test -- --grep "SharedCacheManager"`
Expected: PASS

**步骤 5: 提交**

```bash
git add services/clsi/app/js/SharedCacheManager.js services/clsi/test/unit/src/SharedCacheManagerTests.js
git commit -m "feat: add SharedCacheManager for cross-project cache sharing"
```

---

### Task 3: 集成缓存模块到 CompileManager

**目标：** 在编译流程中使用增强的缓存

**文件：**
- 修改: `services/clsi/app/js/CompileManager.js`

**步骤 1: 修改 CompileManager**

```javascript
// services/clsi/app/js/CompileManager.js 添加
const CacheInvalidator = require('./CacheInvalidator')
const SharedCacheManager = require('./SharedCacheManager')

// 在类初始化中添加
constructor() {
  // ... existing code
  this.cacheInvalidator = new CacheInvalidator()
  this.sharedCacheManager = new SharedCacheManager(redis)
}

// 在 doCompile 方法中添加缓存检查
async doCompile(projectId, projectName, userId, options = {}) {
  // 生成当前编译的缓存键
  const currentCacheKey = this.cacheInvalidator.generateCacheKey({
    compiler: options.compiler,
    rootDoc: options.rootDoc,
    files: options.files,
    imageName: options.imageName
  })

  // 检查是否有共享缓存
  const sharedCache = await this.sharedCacheManager.findSharedCache(
    currentCacheKey,
    options.compiler
  )

  if (sharedCache) {
    logger.info({ projectId }, 'Using shared cache')
    return sharedCache
  }

  // 执行编译
  const result = await this._executeCompile(projectId, options)

  // 存储到共享缓存
  await this.sharedCacheManager.storeSharedCache(currentCacheKey, {
    outputPath: result.outputPath,
    compiler: options.compiler,
    buildId: result.buildId
  })

  return result
}
```

**步骤 2: 运行测试验证通过**

Run: `cd services/clsi && npm test -- --grep "CompileManager"`
Expected: PASS

**步骤 3: 提交**

```bash
git add services/clsi/app/js/CompileManager.js
git commit -m "feat: integrate CacheInvalidator and SharedCacheManager into CompileManager"
```

---

## 验证清单

- [ ] CacheInvalidator 模块已创建
- [ ] SharedCacheManager 模块已创建
- [ ] 单元测试通过
- [ ] 集成到 CompileManager
- [ ] 部署文档已创建
