# -*- encoding: utf-8 -*-

class Member 
  include Mongoid::Document
  include Redis::Objects

  # Referenced
  belongs_to :trade,  foreign_key: 'biz_order_id' # 交易
  belongs_to :user,   foreign_key: 'seller_nick'  # 店铺
  # Embedded
  embeds_many :receivers

  # Fields
  field :grade,             type: Integer,  default: 0
  field :trade_count,       type: Integer
  field :close_trade_count, type: Integer
  field :item_num,          type: Integer
  field :relation_source,   type: Integer
  
  field :buyer_id,          type: Integer
  field :seller_id,         type: Integer

  field :trade_amount,       type: Float,  default: 0 
  field :close_trade_amount, type: Float,  default: 0 

  field :group_ids,          type: Array,  default: []

  field :biz_order_id,      type: String
  field :buyer_nick,        type: String
  field :seller_nick,       type: String
  field :status,            type: String

  field :last_trade_time,   type: DateTime
  field :synced_at,         type: DateTime

  key :seller_id, :buyer_id

  index :last_trade_time, Mongo::DESCENDING

  default_scope desc(:last_trade_time) # 默认排序

  # after_save :cache_receivers

  def cache_receivers
    if synced_at.nil?
      trade = Trade.where(tid: biz_order_id).last
      if trade
        current_receiver = nil
        self.synced_at = Time.now
        unless receivers.empty?
          current_receiver = receivers.where(
            receiver_mobile: trade.receiver_mobile,
            receiver_name: trade.receiver_name,
            receiver_address: trade.receiver_address,
          ).last
        end
        # 检测：手机号、姓名、地址，是否存在。
        if current_receiver.nil?
          specs = mobile_specs(trade.receiver_mobile)
          self.receivers << Receiver.new({
            receiver_address: trade.receiver_address,
            receiver_city: trade.receiver_city,
            receiver_district: trade.receiver_district,
            receiver_mobile: trade.receiver_mobile,
            receiver_name: trade.receiver_name,
            receiver_state: trade.receiver_state, 
            receiver_zip: trade.receiver_zip,
            mobile_carrier: specs[:carrier],
            mobile_network: specs[:network],
          })
        end
        self.save
      end
    end
  end

  def mobile_specs(mobile)
    mobile = mobile.to_s[0..2].to_i # 号段
    china_mobile = { 
      '2G' => [134, 135, 136, 137, 138, 139, 150, 151, 152, 157, 158, 159, 182], 
      '3G' => [187, 188]
    }
    china_unicom = { 
      '2G' => [130, 131, 132, 155, 156], 
      '3G' => [185, 186]
    }
    china_telecom = { 
      '2G' => [133, 153], 
      '3G' => [180, 189]
    }
    case
    when china_mobile['2G'].include?(mobile)
      { carrier: '中国移动', network: '2G' }
    when china_mobile['3G'].include?(mobile)
      { carrier: '中国移动', network: '3G' }
    when china_unicom['2G'].include?(mobile)
      { carrier: '中国联通', network: '2G' }
    when china_unicom['3G'].include?(mobile)
      { carrier: '中国联通', network: '3G' }
    when china_telecom['2G'].include?(mobile)
      { carrier: '中国电信', network: '2G' }
    when china_telecom['3G'].include?(mobile)
      { carrier: '中国电信', network: '3G' }
    else
      { carrier: mobile, network: mobile }
    end
  end

  def trade_pre
    avg = (trade_amount.to_f / trade_count.to_f)
    avg > 0 ? avg.round(2) : nil
  end

  class << self
    
    def sync_create(user, options = {}, current_page=1, page_size=100) # 賣家
        seller_id   = user.user_id
        seller_nick = user.nick
        session     = user.session
        options = { # 基础参数
          session: session, 
          method: 'taobao.crm.members.get', 
          current_page: current_page,
          page_size: page_size, 
        }.merge!(options)
        # 执行
        process_sync(seller_id, seller_nick, options)
    end

    def sync_update(user, start_at, end_at, grade=nil, current_page=1, page_size=100) # 賣家
        seller_id   = user.user_id
        seller_nick = user.nick
        session     = user.session
        options = { # 基础参数
          session: session, 
          method: 'taobao.crm.members.increment.get', 
          start_modify: start_at.strftime("%Y-%m-%d %H:%M:%S"), 
          end_modify: end_at.strftime("%Y-%m-%d %H:%M:%S"), 
          current_page: current_page,
          page_size: page_size, 
        }
        # 会员等级
        options = {grade: grade}.merge!(options) unless grade.nil?
        # 执行
        process_sync(seller_id, seller_nick, options)
    end

    private

    def process_sync(id, nick, options, total_page = 0)
      result = []
      # 获取交易数据
      members = Topsdk.get_with(options)
      # 判断结果
      if members.is_a?(Hash) && members.has_key?('total_result')
        # 分页参数
        total_result = members['total_result'].to_i # 总数
        current_page = options[:current_page].to_i             # 页数
        # 判断记录数
        if total_result > 0
           if total_page == 0 # 总页数
              page_size = options[:page_size].to_i    # 每页数
             total_page = (total_result / page_size)
             total_page += 1 if (total_result % page_size) > 0
           end
           members = members['members']['basic_member'] # 
           if members.count > 0
             members.each do |member| # 循环
               member['seller_nick'] = nick
               member['seller_id']   = id
               member['group_ids']   = member['group_ids'].to_s.split('|')
               member_id = "#{id}-#{member['buyer_id']}"
               # 已有
               current_member = where(_id: member_id).last
               if current_member.nil?
                  result << member
                  Member.create(member)        
               elsif member['last_trade_time'].to_time > current_member.last_trade_time
                  result << member
                  member['synced_at'] = nil
                  current_member.update_attributes(member)
               end
             end
           end
           if members.count != result.count
             puts "Member.process_sync============================错误"
             puts (members - result)
           end 
           # 循环
           process_sync(id, nick, options.merge!(current_page: (current_page + 1)), total_page) if total_page > current_page
        else
          if total_page > 0
             puts "Member.process_sync============================重试"
             process_sync(id, nick, options, total_page)
           else
             puts "Member.process_sync============================错误"
             puts "======请======求======"
             puts options
             puts "======结======果======"
             puts members
           end
        end
      else
        if total_page > 0
           puts "Member.process_sync============================重试"
           process_sync(id, nick, options, total_page)
         else
           puts "Member.process_sync============================错误"
           puts "======请======求======"
           puts options
           puts "======结======果======"
           puts members
         end
      end
    end
  end
end