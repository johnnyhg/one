# -*- encoding: utf-8 -*-

# 数据库
Resque.redis              = REDIS_URL
Resque.redis.namespace    = 'resque:One'
# 加载计划的配置
Resque::Scheduler.dynamic = true