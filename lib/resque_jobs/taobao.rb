# -*- encoding: utf-8 -*-
require 'resque/errors'

module ResqueJobs
  
  class ResqueJob
    # 卖家
    def self.find_by_nick(user_id)
      User.where(_id: user_id).first
    end
  end
  
  class SyncUser < ResqueJob
    @queue = :base

    def self.perform(user_id)
      user  = find_by_nick(user_id)
      if user
          user.subusers_sync  # 店铺子账户
          user.rates_sync     # 店铺评价
          user.addresses_sync # 仓储地址
          user.chatpeers_sync # 旺旺接待
          user.wangwangs_sync # 记录旺旺统计
          user.members_sync   # 卖家的会员
      end
    rescue Resque::TermException
      puts "=================同步错误：店铺信息=================="
    end
  end

  class SyncTrade < ResqueJob 
    @queue = :trades
    
    def self.perform(user_id)
      user = find_by_nick(user_id)
      if user
        puts "=================开始同步#{user_id}交易信息=================="
          user.trades_sync # 交易
          user.orders_sync # 订单
          user.refunds_sync # 退款
        puts "=================结束同步#{user_id}交易信息=================="
      end
    rescue Resque::TermException
      puts "=================同步错误：交易信息=================="
    end
  end
  
  class SyncItem < ResqueJob
    @queue = :items
      
    def self.perform(user_id)
      user = find_by_nick(user_id)
      if user
        puts "=================开始同步#{user_id}货品信息=================="
          user.items_sync  # 货品
        puts "=================结束同步#{user_id}货品信息=================="
      end
    rescue Resque::TermException
      puts "=================同步错误：货品信息=================="
    end
  end

  class SyncShipping < ResqueJob
    @queue = :shippings
      
    def self.perform(user_id)
      user = find_by_nick(user_id)
      if user
        puts "=================开始同步#{user_id}物流信息=================="
          user.shippings_sync  # 物流
        puts "=================结束同步#{user_id}物流信息=================="
      end
    rescue Resque::TermException
      puts "=================同步错误：物流信息=================="
    end
  end
end